using Microsoft.Win32;
using MotWUnblocker.Models;
using MotWUnblocker.Services;
using MotWUnblocker.Utils;
using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;

namespace MotWUnblocker
{
    public partial class MainWindow : Window
    {
        private readonly ObservableCollection<FileEntry> _files = new();
        private const string NoFilesSelectedMessage = "No files selected.";
        private bool _isProcessing;

        public MainWindow()
        {
            InitializeComponent();
            DataContext = _files;
            Logger.Info("Application started.");

            // Add keyboard shortcuts
            KeyDown += MainWindow_KeyDown;
        }

        private void MainWindow_KeyDown(object sender, KeyEventArgs e)
        {
            if (_isProcessing) return;

            // Ctrl+O - Add Files
            if (e.Key == Key.O && Keyboard.Modifiers == ModifierKeys.Control)
            {
                AddFiles_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
            // Delete - Remove Selected
            else if (e.Key == Key.Delete)
            {
                RemoveSelected_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
            // Ctrl+L - Clear All
            else if (e.Key == Key.L && Keyboard.Modifiers == ModifierKeys.Control)
            {
                ClearAll_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
            // F5 - Refresh
            else if (e.Key == Key.F5)
            {
                Refresh_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
            // Ctrl+U - Unblock
            else if (e.Key == Key.U && Keyboard.Modifiers == ModifierKeys.Control)
            {
                UnblockSelected_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
            // Ctrl+B - Block
            else if (e.Key == Key.B && Keyboard.Modifiers == ModifierKeys.Control)
            {
                BlockSelected_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
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

        private void ClearAll_Click(object sender, RoutedEventArgs e)
        {
            if (_files.Count == 0)
            {
                SetStatus("No files to clear.");
                return;
            }

            var count = _files.Count;
            _files.Clear();
            SetStatus($"Cleared {count} file(s).");
            Logger.Info($"Cleared all files from list ({count} files)");
        }

        private async void Refresh_Click(object sender, RoutedEventArgs e)
        {
            if (_isProcessing) return;

            SetProcessingState(true);
            SetStatus("Refreshing status...");

            var filesToRefresh = _files.ToList();

            await Task.Run(() =>
            {
                foreach (var f in filesToRefresh)
                {
                    f.HasMotW = MotWService.HasMotW(f.FullPath);
                }
            });

            SetStatus($"Status refreshed for {filesToRefresh.Count} file(s).");
            SetProcessingState(false);
        }

        private async void UnblockSelected_Click(object sender, RoutedEventArgs e)
        {
            if (_isProcessing) return;

            var targets = _files.Where(f => f.Selected && File.Exists(f.FullPath)).ToList();
            if (targets.Count == 0)
            {
                SetStatus(NoFilesSelectedMessage);
                return;
            }

            SetProcessingState(true);

            var (ok, fail) = await ProcessFilesAsync(targets, async (file) =>
            {
                return await Task.Run(() =>
                {
                    var result = MotWService.Unblock(file.FullPath, out var error);
                    if (result)
                    {
                        Dispatcher.Invoke(() => file.HasMotW = false);
                    }
                    return result;
                });
            });

            SetStatus($"Unblock complete. Success: {ok}, Failed: {fail}");
            SetProcessingState(false);
        }

        private async void BlockSelected_Click(object sender, RoutedEventArgs e)
        {
            if (_isProcessing) return;

            var targets = _files.Where(f => f.Selected && File.Exists(f.FullPath)).ToList();
            if (targets.Count == 0)
            {
                SetStatus(NoFilesSelectedMessage);
                return;
            }

            SetProcessingState(true);

            var (ok, fail) = await ProcessFilesAsync(targets, async (file) =>
            {
                return await Task.Run(() =>
                {
                    var result = MotWService.Block(file.FullPath, out var error);
                    if (result)
                    {
                        Dispatcher.Invoke(() => file.HasMotW = true);
                    }
                    return result;
                });
            });

            SetStatus($"Block (add MotW) complete. Success: {ok}, Failed: {fail}");
            SetProcessingState(false);
        }

        private async Task<(int success, int failed)> ProcessFilesAsync(
            List<FileEntry> files,
            Func<FileEntry, Task<bool>> operation)
        {
            int ok = 0, fail = 0;
            int total = files.Count;

            for (int i = 0; i < files.Count; i++)
            {
                var file = files[i];
                SetStatus($"Processing {i + 1}/{total}: {file.Name}");

                try
                {
                    var result = await operation(file);
                    if (result)
                        ok++;
                    else
                        fail++;
                }
                catch (Exception ex)
                {
                    Logger.Error($"Error processing {file.FullPath}: {ex.Message}");
                    fail++;
                }
            }

            return (ok, fail);
        }

        private void SetProcessingState(bool isProcessing)
        {
            _isProcessing = isProcessing;
            Mouse.OverrideCursor = isProcessing ? Cursors.Wait : null;

            // Disable all buttons during processing
            foreach (var button in Toolbar.Items.OfType<System.Windows.Controls.Button>())
            {
                button.IsEnabled = !isProcessing;
            }
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
