using System.ComponentModel;
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

        public string SizeDisplay => $"{SizeBytes:n0} B";
        public string ModifiedLocal => ModifiedUtc.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss");

        public FileEntry(string fullPath, string name, string extension, long sizeBytes, DateTime modifiedUtc, bool hasMotw)
        {
            FullPath = fullPath;
            Name = name;
            Extension = extension;
            SizeBytes = sizeBytes;
            ModifiedUtc = modifiedUtc;
            _hasMotw = hasMotw;
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        private void OnPropertyChanged([CallerMemberName] string? prop = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(prop));
    }
}
