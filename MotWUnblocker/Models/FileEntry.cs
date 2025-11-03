using System.ComponentModel;
using System.Globalization;
using System.Runtime.CompilerServices;

namespace MotWUnblocker.Models
{
    public class FileEntry : INotifyPropertyChanged
    {
        private bool _selected;
        private bool _hasMotw;

        public string FullPath { get; }
        public string Name { get; }
        public string Extension { get; }
        public long SizeBytes { get; }
        public DateTime ModifiedUtc { get; }

        public bool Selected
        {
            get => _selected;
            set { _selected = value; OnPropertyChanged(); }
        }

        public bool HasMotW
        {
            get => _hasMotw;
            set { _hasMotw = value; OnPropertyChanged(); }
        }

        public string SizeDisplay => FormatBytes(SizeBytes);
        public string ModifiedLocal => ModifiedUtc.ToLocalTime().ToString("G", CultureInfo.CurrentCulture);

        public FileEntry(string fullPath, string name, string extension, long sizeBytes, DateTime modifiedUtc, bool hasMotw)
        {
            if (string.IsNullOrWhiteSpace(fullPath))
                throw new ArgumentException("File path cannot be null or empty.", nameof(fullPath));
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("File name cannot be null or empty.", nameof(name));
            if (sizeBytes < 0)
                throw new ArgumentOutOfRangeException(nameof(sizeBytes), "File size cannot be negative.");

            FullPath = fullPath;
            Name = name;
            Extension = extension ?? string.Empty;
            SizeBytes = sizeBytes;
            ModifiedUtc = modifiedUtc;
            _hasMotw = hasMotw;
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes == 0) return "0 B";
            if (bytes < 0) return "Invalid";

            string[] sizes = { "B", "KB", "MB", "GB", "TB" };
            double len = bytes;
            int order = 0;

            while (len >= 1024 && order < sizes.Length - 1)
            {
                order++;
                len /= 1024;
            }

            // Use appropriate precision based on size
            string format = order == 0 ? "0" : "0.##";
            return $"{len.ToString(format, CultureInfo.InvariantCulture)} {sizes[order]}";
        }

        public override string ToString() => $"{Name} ({SizeDisplay}) - MotW: {HasMotW}";

        public event PropertyChangedEventHandler? PropertyChanged;
        private void OnPropertyChanged([CallerMemberName] string? prop = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(prop));
    }
}
