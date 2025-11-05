using System.IO;
using System.Text.Json;
using MotW.Shared.Utils;
using MotWatcher.Models;

namespace MotWatcher.Services
{
    public static class ConfigService
    {
        private static readonly string ConfigDir =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MotW");

        private static readonly string ConfigPath = Path.Combine(ConfigDir, "watcher-config.json");

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            WriteIndented = true,
            PropertyNameCaseInsensitive = true
        };

        static ConfigService()
        {
            try
            {
                Directory.CreateDirectory(ConfigDir);
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to create config directory: {ex.Message}");
            }
        }

        public static WatcherConfig Load()
        {
            try
            {
                if (!File.Exists(ConfigPath))
                {
                    Logger.Info("No existing config found, creating default configuration.");
                    var defaultConfig = CreateDefaultConfig();
                    Save(defaultConfig);
                    return defaultConfig;
                }

                var json = File.ReadAllText(ConfigPath);
                var config = JsonSerializer.Deserialize<WatcherConfig>(json, JsonOptions);

                if (config == null)
                {
                    Logger.Warn("Config deserialization returned null, using default.");
                    return CreateDefaultConfig();
                }

                Logger.Info($"Loaded configuration with {config.WatchedDirectories.Count} watched directories.");
                return config;
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load config: {ex.Message}");
                return CreateDefaultConfig();
            }
        }

        public static void Save(WatcherConfig config)
        {
            ArgumentNullException.ThrowIfNull(config);

            try
            {
                var json = JsonSerializer.Serialize(config, JsonOptions);
                File.WriteAllText(ConfigPath, json);
                Logger.Info($"Configuration saved with {config.WatchedDirectories.Count} watched directories.");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save config: {ex.Message}");
            }
        }

        private static WatcherConfig CreateDefaultConfig()
        {
            var downloadsPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "Downloads"
            );

            var config = new WatcherConfig
            {
                AutoStart = false,
                StartWatchingOnLaunch = false,
                NotifyOnProcess = true,
                DebounceDelayMs = 2000
            };

            // Add Downloads folder as default watched directory if it exists
            if (Directory.Exists(downloadsPath))
            {
                config.WatchedDirectories.Add(new WatchedDirectory
                {
                    Path = downloadsPath,
                    Enabled = true,
                    IncludeSubdirectories = false,
                    MinZoneId = 3 // Only process files from Internet zone
                });
            }

            return config;
        }

        public static string ConfigDirectory => ConfigDir;
        public static string ConfigFilePath => ConfigPath;
    }
}
