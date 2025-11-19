#!/usr/bin/env python3
"""
Example: Using MCP Toggle with Python Scripts

This example shows how to integrate MCP Toggle's global configuration
into your Python scripts for programmatic AI interactions.
"""

import json
import subprocess
from pathlib import Path


def load_mcp_config():
    """Load the global MCP configuration."""
    config_path = Path.home() / '.mcp' / 'global-config.json'

    if not config_path.exists():
        raise FileNotFoundError(
            f"MCP config not found at {config_path}. "
            "Run ./install.sh first!"
        )

    with open(config_path) as f:
        return json.load(f)


def run_claude_with_mcp(prompt, config_path=None):
    """
    Run Claude Code with MCP configuration.

    Args:
        prompt (str): The prompt to send to Claude
        config_path (Path, optional): Path to MCP config. Defaults to global config.

    Returns:
        subprocess.CompletedProcess: The result of the Claude execution
    """
    if config_path is None:
        config_path = Path.home() / '.mcp' / 'global-config.json'

    # Read the config file
    with open(config_path) as f:
        config = f.read()

    # Run Claude with MCP config
    result = subprocess.run([
        'claude',
        '--strict-mcp-config',
        '--mcp-config', config,
        '--print', prompt
    ], capture_output=True, text=True)

    return result


def main():
    """Example usage."""
    print("Loading MCP configuration...")
    config = load_mcp_config()

    # Show available MCP servers
    enabled_servers = list(config.get('mcpServers', {}).keys())
    disabled_servers = list(config.get('_disabled_mcpServers', {}).keys())

    print(f"✓ Enabled MCP servers: {', '.join(enabled_servers)}")
    if disabled_servers:
        print(f"✗ Disabled MCP servers: {', '.join(disabled_servers)}")

    # Example: Run a search query
    print("\nRunning example query...")
    result = run_claude_with_mcp(
        "Use brave-search to find the latest news about AI"
    )

    if result.returncode == 0:
        print("✓ Query successful!")
        print(f"\nResult:\n{result.stdout}")
    else:
        print(f"✗ Query failed: {result.stderr}")


if __name__ == '__main__':
    main()
