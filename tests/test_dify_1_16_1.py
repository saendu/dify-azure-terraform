import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def hcl_block(source: str, header: str) -> str:
    start = source.find(header)
    if start == -1:
        raise AssertionError(f"missing HCL block: {header}")

    opening = source.find("{", start + len(header))
    if opening == -1:
        raise AssertionError(f"block has no opening brace: {header}")

    depth = 0
    in_string = False
    escaped = False
    for index in range(opening, len(source)):
        character = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            continue

        if character == '"':
            in_string = True
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]

    raise AssertionError(f"unterminated HCL block: {header}")


def variable_block(name: str) -> str:
    return hcl_block(read("var.tf"), f'variable "{name}"')


def resource_block(relative_path: str, resource_type: str, name: str) -> str:
    return hcl_block(read(relative_path), f'resource "{resource_type}" "{name}"')


def env_values(block: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for env_match in re.finditer(r"\benv\s*\{", block):
        env_block = hcl_block(block[env_match.start() :], "env")
        name = re.search(r'\bname\s*=\s*"([A-Z0-9_]+)"', env_block)
        value = re.search(r"\bvalue\s*=\s*([^\n]+)", env_block)
        if name and value:
            values[name.group(1)] = value.group(1).strip()
    return values


class DifyReleaseContractTests(unittest.TestCase):
    def test_release_images(self) -> None:
        expected = {
            "dify-api-image": "langgenius/dify-api:1.16.1",
            "dify-web-image": "langgenius/dify-web:1.16.1",
            "dify-sandbox-image": "langgenius/dify-sandbox:0.2.15",
            "dify-plugin-daemon-image": "langgenius/dify-plugin-daemon:0.6.3-local",
            "dify-agent-backend-image": "langgenius/dify-agent-backend:1.16.1",
            "dify-agent-local-sandbox-image": "langgenius/dify-agent-local-sandbox:1.16.1",
        }
        for name, image in expected.items():
            with self.subTest(variable=name):
                self.assertRegex(variable_block(name), rf'default\s*=\s*"{re.escape(image)}"')

    def test_agent_feature_defaults_enabled(self) -> None:
        self.assertRegex(variable_block("enable-dify-agent-v2"), r"default\s*=\s*true")
        web = resource_block("aca-env.tf", "azurerm_container_app", "web")
        env = env_values(web)
        self.assertEqual(env["NEXT_PUBLIC_ENABLE_AGENT_V2"], "tostring(var.enable-dify-agent-v2)")
        self.assertEqual(env["NEXT_PUBLIC_ENABLE_FEATURE_PREVIEW"], '"true"')

    def test_existing_timeouts_are_preserved(self) -> None:
        expected = {
            "PYTHON_ENV_INIT_TIMEOUT": '"120"',
            "PLUGIN_MAX_EXECUTION_TIMEOUT": '"600"',
            "WORKER_TIMEOUT": '"15"',
            "FILES_ACCESS_TIMEOUT": '"300"',
            "PLUGIN_DAEMON_TIMEOUT": '"600.0"',
            "TEXT_GENERATION_TIMEOUT_MS": '"60000"',
            "WORKFLOW_MAX_EXECUTION_TIME": '"1200"',
            "ACCESS_TOKEN_EXPIRE_MINUTES": '"60"',
            "REFRESH_TOKEN_EXPIRE_DAYS": '"30"',
            "SQLALCHEMY_POOL_RECYCLE": '"3600"',
        }
        env = env_values(read("aca-env.tf"))
        for name, value in expected.items():
            with self.subTest(timeout=name):
                self.assertEqual(env.get(name), value)

    def test_generated_agent_secrets(self) -> None:
        secrets = read("secrets.tf")
        keyvault = read("keyvault.tf")
        for name in ("dify_agent_api_token", "dify_agent_shellctl_auth_token"):
            with self.subTest(secret=name):
                random_secret = hcl_block(secrets, f'resource "random_password" "{name}"')
                self.assertRegex(random_secret, r"length\s*=\s*64")
                self.assertRegex(random_secret, r"special\s*=\s*false")
                vault_secret = hcl_block(keyvault, f'resource "azurerm_key_vault_secret" "{name}"')
                self.assertIn(f"local.{name}_value", vault_secret)

        server_secret = hcl_block(secrets, 'resource "random_bytes" "dify_agent_server_secret_key"')
        self.assertRegex(server_secret, r"length\s*=\s*32")
        self.assertRegex(
            secrets,
            r'dify_agent_server_secret_key_value\s*=\s*replace\(replace\(replace\('
            r'random_bytes\.dify_agent_server_secret_key\.base64,\s*"\+",\s*"-"\),\s*"/",\s*"_"\),\s*"=",\s*""\)',
        )
        vault_secret = hcl_block(
            keyvault, 'resource "azurerm_key_vault_secret" "dify_agent_server_secret_key"'
        )
        self.assertIn("local.dify_agent_server_secret_key_value", vault_secret)

    def test_nginx_release_routes(self) -> None:
        nginx = read("mountfiles/nginx/conf.d/default.conf")
        for route in ("/openapi", "/socket.io/", "/e/", "/mcp", "/triggers"):
            with self.subTest(route=route):
                self.assertRegex(nginx, rf"location\s+{re.escape(route)}")
        self.assertIn("proxy_set_header Upgrade $http_upgrade;", nginx)
        self.assertIn("proxy_pass http://plugindaemon:5002;", nginx)

    def test_main_ssrf_blocks_private_networks(self) -> None:
        common = read("mountfiles/ssrfproxy/dify_common.conf")
        policy = read("mountfiles/ssrfproxy/squid.conf")
        self.assertIn("acl to_private_networks dst 10.0.0.0/8", common)
        self.assertIn("acl to_private_networks dst 169.254.0.0/16", common)
        self.assertIn("http_access deny to_private_networks", policy)
        self.assertNotIn("http_port 8194 accel", policy)
        self.assertNotIn("include /etc/squid/conf.d", policy)

    def test_agent_ssrf_policy(self) -> None:
        policy = read("mountfiles/agent-ssrfproxy/squid.conf")
        self.assertIn("acl dst_agent_backend dstdomain agentbackend", policy)
        self.assertIn("acl dst_dify_api dstdomain api", policy)
        self.assertIn("acl path_files urlpath_regex -i ^/files/", policy)
        self.assertIn("acl path_agent_stub urlpath_regex -i ^/agent-stub/", policy)
        self.assertLess(
            policy.index("http_access allow dst_agent_backend path_agent_stub"),
            policy.index("http_access deny to_private_networks"),
        )
        self.assertLess(
            policy.index("http_access deny to_private_networks"),
            policy.index("http_access allow all"),
        )

    def test_agent_container_apps(self) -> None:
        proxy = resource_block("agent.tf", "azurerm_container_app", "agent_ssrf_proxy")
        sandbox = resource_block("agent.tf", "azurerm_container_app", "local_sandbox")
        backend = resource_block("agent.tf", "azurerm_container_app", "agent_backend")

        for name, block, port in (
            ("proxy", proxy, 3128),
            ("sandbox", sandbox, 5004),
            ("backend", backend, 5050),
        ):
            with self.subTest(service=name):
                self.assertRegex(block, r"external_enabled\s*=\s*false")
                self.assertRegex(block, rf"target_port\s*=\s*{port}")
                self.assertRegex(block, r"min_replicas\s*=\s*1")
                self.assertRegex(block, r"max_replicas\s*=\s*1")

        sandbox_env = env_values(sandbox)
        self.assertEqual(sandbox_env["HTTP_PROXY"], '"http://agentssrfproxy:3128"')
        self.assertEqual(sandbox_env["HTTPS_PROXY"], '"http://agentssrfproxy:3128"')
        self.assertEqual(sandbox_env["SHELLCTL_ENABLE_PATH_ISOLATION"], '"true"')

    def test_agent_authentication_wiring(self) -> None:
        api_env = env_values(resource_block("aca-env.tf", "azurerm_container_app", "api"))
        worker_env = env_values(resource_block("aca-env.tf", "azurerm_container_app", "worker"))
        backend_env = env_values(resource_block("agent.tf", "azurerm_container_app", "agent_backend"))
        sandbox_env = env_values(resource_block("agent.tf", "azurerm_container_app", "local_sandbox"))

        shared_api_token = "azurerm_key_vault_secret.dify_agent_api_token.value"
        for name, env in (("api", api_env), ("worker", worker_env)):
            with self.subTest(service=name):
                self.assertEqual(env["AGENT_BACKEND_BASE_URL"], '"http://agentbackend:5050"')
                self.assertEqual(env["AGENT_BACKEND_API_TOKEN"], shared_api_token)
                self.assertEqual(env["AGENT_BACKEND_STREAM_READ_TIMEOUT_SECONDS"], '"30"')
                self.assertEqual(env["AGENT_BACKEND_STREAM_MAX_RECONNECTS"], '"3"')
                self.assertEqual(env["AGENT_BACKEND_RUN_TIMEOUT_SECONDS"], '"1200"')

        self.assertEqual(backend_env["DIFY_AGENT_API_TOKEN"], shared_api_token)
        self.assertEqual(
            backend_env["DIFY_AGENT_SERVER_SECRET_KEY"],
            "azurerm_key_vault_secret.dify_agent_server_secret_key.value",
        )
        shell_token = "azurerm_key_vault_secret.dify_agent_shellctl_auth_token.value"
        self.assertEqual(backend_env["DIFY_AGENT_SHELLCTL_AUTH_TOKEN"], shell_token)
        self.assertEqual(sandbox_env["SHELLCTL_AUTH_TOKEN"], shell_token)

    def test_required_data_services(self) -> None:
        postgres = read("postgresql.tf")
        self.assertIn('resource "azurerm_postgresql_flexible_server_database" "difypgsqldb"', postgres)
        self.assertIn('resource "azurerm_postgresql_flexible_server_database" "pgvector"', postgres)
        self.assertIn('resource "azurerm_postgresql_flexible_server_database" "dify_plugin"', postgres)
        extension = resource_block(
            "postgresql.tf", "azurerm_postgresql_flexible_server_configuration", "extension"
        )
        self.assertIn('value     = "vector,uuid-ossp"', extension)
        self.assertIn('resource "azurerm_redis_cache" "redis"', read("redis-cache.tf"))


if __name__ == "__main__":
    unittest.main()
