use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AppConfig {
    pub api_key: String,
    pub port: u16,
    pub query_port: u16,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            api_key: String::new(),
            port: 5899,
            query_port: 10011,
        }
    }
}

pub fn get_config_path() -> Result<PathBuf> {
    let mut exe_path = env::current_exe().context("Failed to get current exe path")?;
    exe_path.pop(); // Go to parent directory
    exe_path.push("config.json");
    Ok(exe_path)
}

pub fn load_config() -> Result<AppConfig> {
    let path = get_config_path()?;
    if !path.exists() {
        return Ok(AppConfig::default());
    }
    let content = fs::read_to_string(&path)?;
    let config: AppConfig = serde_json::from_str(&content)?;
    Ok(config)
}

pub fn save_config(config: &AppConfig) -> Result<()> {
    let path = get_config_path()?;
    let content = serde_json::to_string_pretty(config)?;
    fs::write(&path, content)?;
    Ok(())
}
