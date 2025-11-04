using System.Collections.ObjectModel;

namespace MotWatcher.Models
{
    public class WatcherConfig
    {
        public bool AutoStart { get; set; } = false;
        public bool StartWatchingOnLaunch { get; set; } = false;
        public bool NotifyOnProcess { get; set; } = true;
        public int DebounceDelayMs { get; set; } = 2000;
        public ObservableCollection<WatchedDirectory> WatchedDirectories { get; set; } = new();
    }

    public class WatchedDirectory
    {
        public string Path { get; set; } = string.Empty;
        public bool Enabled { get; set; } = true;
        public bool IncludeSubdirectories { get; set; } = false;
        public ObservableCollection<string> FileTypeFilters { get; set; } = new() { "*" };

        /// <summary>
        /// Minimum Zone ID to process. Files below this threshold will be ignored.
        /// null = process all zones, 3 = Internet and above, 2 = Trusted and above, etc.
        /// </summary>
        public int? MinZoneId { get; set; } = 3;

        /// <summary>
        /// Target Zone ID to reassign files to.
        /// 0 = Local Machine, 1 = Local Intranet, 2 = Trusted Sites
        /// If null, the MotW will be removed entirely (not recommended for security).
        /// </summary>
        public int? TargetZoneId { get; set; } = 2; // Default to Trusted Sites

        /// <summary>
        /// Exclude patterns (glob-style). Files matching these patterns will be skipped.
        /// Examples: "*.part", "*.tmp", "*.7z.*"
        /// </summary>
        public ObservableCollection<string> ExcludePatterns { get; set; } = new();
    }
}
