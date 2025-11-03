using Microsoft.Win32;
using MotWUnblocker.Models;
using MotWUnblocker.Services;
using MotWUnblocker.Utils;
using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Input;

namespace MotWUnblocker
{
    public partial class MainWindow : Window
    {
        private readonly ObservableCollection<FileEntry> _files = new();

        public MainWindow()
        {
            InitializeComponent();
            DataContext = _files;
            Logger.Info("Application started.");
        }

        private void AddFiles_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog
            {
                Title = "Select files",
                CheckFileExists = true,
                Multiselect = true,
                Filter = "All files (*.*)|*.*"
            };
            if (dlg.ShowDialog() == true)
            {
                AddFiles(dlg.FileNames);
            }
        }

        private void RemoveSelected_Click(object sender, RoutedEventArgs e)
        {
            var toRemove = _files.Where(f => f.Selected).ToList();
            foreach (var f in toRemove)
                _files.Remove(f);
            SetStatus($"Removed {toRemove.Count} file(s).");
        }

        private void Refresh_Click(object sender, RoutedEventArgs e)
        {
            foreach (var f in _files)
            {
                f.HasMotW = MotWService.HasMotW(f.FullPath);
            }
            SetStatus("Status refreshed.");
        }

        private void UnblockSelected_Click(object sender, RoutedEventArgs e)
        {
            var targets = _files.Where(f => f.Selected).ToList();
            if (targets.Count == 0) { SetStatus("No files selected."); return; }

            int ok = 0, fail = 0;
            foreach (var f in targets)
            {
                if (!File.Exists(f.FullPath))
                {
                    fail++;
                    Logger.Warn($"Missing file: {f.FullPath}");
                    continue;
                }
                var result = MotWService.Unblock(f.FullPath, out var err);
                if (result)
                {
                    ok++;
                    f.HasMotW = false;
                    Logger.Info($"Unblocked: {f.FullPath}");
                }
                else
                {
                    fail++;
                    Logger.Error($"Unblock failed: {f.FullPath} :: {err}");
                }
            }
            SetStatus($"Unblock complete. Success: {ok}, Failed: {fail}");
        }

        private void BlockSelected_Click(object sender, RoutedEventArgs e)
        {
            var targets = _files.Where(f => f.Selected).ToList();
            if (targets.Count == 0) { SetStatus("No files selected."); return; }

            int ok = 0, fail = 0;
            foreach (var f in targets)
            {
                if (!File.Exists(f.FullPath))
                {
                    fail++;
                    Logger.Warn($"Missing file: {f.FullPath}");
                    continue;
                }
                var result = MotWService.Block(f.FullPath, out var err);
                if (result)
                {
                    ok++;
                    f.HasMotW = true;
                    Logger.Info($"Blocked (MotW added): {f.FullPath}");
                }
                else
                {
                    fail++;
                    Logger.Error($"Block failed: {f.FullPath} :: {err}");
                }
            }
            SetStatus($"Block (add MotW) complete. Success: {ok}, Failed: {fail}");
        }

        private void OpenLogFolder_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var folder = Logger.LogFolder;
                Directory.CreateDirectory(folder);
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = folder,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, "Unable to open log folder: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void AddFiles(string[] paths)
        {
            int added = 0, skipped = 0;
            foreach (var p in paths.Distinct())
            {
                try
                {
                    if (!File.Exists(p)) { skipped++; continue; }
                    if (_files.Any(f => string.Equals(f.FullPath, p, StringComparison.OrdinalIgnoreCase)))
                    {
                        skipped++; continue;
                    }
                    var fi = new FileInfo(p);
                    var entry = new FileEntry(
                        fullPath: fi.FullName,
                        name: fi.Name,
                        extension: fi.Extension,
                        sizeBytes: fi.Length,
                        modifiedUtc: fi.LastWriteTimeUtc,
                        hasMotw: MotWService.HasMotW(fi.FullName)
                    );
                    _files.Add(entry);
                    added++;
                }
                catch (Exception ex)
                {
                    Logger.Error($"Add file failed: {p} :: {ex.Message}");
                    skipped++;
                }
            }
            SetStatus($"Added {added}, skipped {skipped}.");
        }

        private void Window_Drop(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                var paths = (string[])e.Data.GetData(DataFormats.FileDrop);
                AddFiles(paths);
            }
        }

        private void Window_DragOver(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effects = DragDropEffects.Copy;
                e.Handled = true;
            }
        }

        private void SetStatus(string text)
        {
            StatusText.Text = text;
        }
    }
}
