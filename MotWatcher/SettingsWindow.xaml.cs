using System.Collections.ObjectModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Forms;
using Microsoft.Win32;
using MotW.Shared.Utils;
using MotWatcher.Models;
using MotWatcher.Services;
using Application = System.Windows.Application;
using MessageBox = System.Windows.MessageBox;

namespace MotWatcher
{
    public partial class SettingsWindow : Window
    {
        private WatcherConfig _config;
        private WatchedDirectory? _selectedDirectory;

        public SettingsWindow(WatcherConfig config)
        {
            InitializeComponent();
            _config = config;
            LoadSettings();
        }

        private void LoadSettings()
        {
            // General settings
            AutoStartCheckBox.IsChecked = _config.AutoStart;
            NotifyOnProcessCheckBox.IsChecked = _config.NotifyOnProcess;
            DebounceSlider.Value = _config.DebounceDelayMs / 1000.0;

            // Check if StartWatchingOnLaunch exists in config
            var configType = _config.GetType();
            var startWatchingProp = configType.GetProperty("StartWatchingOnLaunch");
            if (startWatchingProp != null)
            {
                StartWatchingOnLaunchCheckBox.IsChecked = (bool?)startWatchingProp.GetValue(_config) ?? false;
            }
            else
            {
                StartWatchingOnLaunchCheckBox.IsChecked = false;
            }

            // Directories
            DirectoriesGrid.ItemsSource = _config.WatchedDirectories;
        }

        private void DebounceSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            if (DebounceValueText != null)
            {
                DebounceValueText.Text = $"{e.NewValue:F1}s";
            }
        }

        private void DirectoriesGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            _selectedDirectory = DirectoriesGrid.SelectedItem as WatchedDirectory;
            bool hasSelection = _selectedDirectory != null;

            EditDirectoryButton.IsEnabled = hasSelection;
            RemoveDirectoryButton.IsEnabled = hasSelection;
            AddFileTypeButton.IsEnabled = hasSelection;

            if (hasSelection && _selectedDirectory != null)
            {
                FileTypesList.ItemsSource = _selectedDirectory.FileTypeFilters;
            }
            else
            {
                FileTypesList.ItemsSource = null;
            }
        }

        private void AddDirectory_Click(object sender, RoutedEventArgs e)
        {
            using (var dialog = new FolderBrowserDialog())
            {
                dialog.Description = "Select a directory to watch";
                dialog.ShowNewFolderButton = false;

                if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                {
                    var path = dialog.SelectedPath;

                    // Check if already exists
                    if (_config.WatchedDirectories.Any(d => d.Path.Equals(path, StringComparison.OrdinalIgnoreCase)))
                    {
                        MessageBox.Show("This directory is already being watched.", "Duplicate Directory",
                            MessageBoxButton.OK, MessageBoxImage.Information);
                        return;
                    }

                    var newDir = new WatchedDirectory
                    {
                        Path = path,
                        Enabled = true,
                        IncludeSubdirectories = false,
                        MinZoneId = 3,
                        FileTypeFilters = new ObservableCollection<string> { "*" }
                    };

                    _config.WatchedDirectories.Add(newDir);
                    DirectoriesGrid.SelectedItem = newDir;
                    Logger.Info($"Added watched directory: {path}");
                }
            }
        }

        private void EditDirectory_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedDirectory == null)
                return;

            var dialog = new EditDirectoryDialog(_selectedDirectory);
            if (dialog.ShowDialog() == true)
            {
                DirectoriesGrid.Items.Refresh();
                Logger.Info($"Updated watched directory: {_selectedDirectory.Path}");
            }
        }

        private void RemoveDirectory_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedDirectory == null)
                return;

            var result = MessageBox.Show(
                $"Remove directory from watched list?\n\n{_selectedDirectory.Path}",
                "Confirm Remove",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (result == MessageBoxResult.Yes)
            {
                Logger.Info($"Removed watched directory: {_selectedDirectory.Path}");
                _config.WatchedDirectories.Remove(_selectedDirectory);
            }
        }

        private void FileTypesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            RemoveFileTypeButton.IsEnabled = FileTypesList.SelectedItem != null;
        }

        private void AddFileType_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedDirectory == null)
                return;

            var dialog = new InputDialog("Add File Type Filter", "Enter file extension (e.g., *.pdf or .pdf):");
            if (dialog.ShowDialog() == true)
            {
                var filter = dialog.Result.Trim();
                if (string.IsNullOrEmpty(filter))
                    return;

                // Normalize format
                if (!filter.StartsWith("*") && !filter.StartsWith("."))
                    filter = "*." + filter;
                else if (filter.StartsWith("."))
                    filter = "*" + filter;

                if (_selectedDirectory.FileTypeFilters.Contains(filter, StringComparer.OrdinalIgnoreCase))
                {
                    MessageBox.Show("This filter already exists.", "Duplicate Filter",
                        MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }

                // Remove "*" if adding specific extension
                if (filter != "*" && _selectedDirectory.FileTypeFilters.Contains("*"))
                {
                    _selectedDirectory.FileTypeFilters.Remove("*");
                }

                _selectedDirectory.FileTypeFilters.Add(filter);
                Logger.Info($"Added file type filter: {filter} to {_selectedDirectory.Path}");
            }
        }

        private void RemoveFileType_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedDirectory == null || FileTypesList.SelectedItem == null)
                return;

            var filter = FileTypesList.SelectedItem.ToString();
            if (filter != null)
            {
                _selectedDirectory.FileTypeFilters.Remove(filter);

                // Ensure at least one filter remains
                if (_selectedDirectory.FileTypeFilters.Count == 0)
                {
                    _selectedDirectory.FileTypeFilters.Add("*");
                }

                Logger.Info($"Removed file type filter: {filter} from {_selectedDirectory.Path}");
            }
        }

        private void Save_Click(object sender, RoutedEventArgs e)
        {
            // Update config from UI
            _config.AutoStart = AutoStartCheckBox.IsChecked ?? false;
            _config.NotifyOnProcess = NotifyOnProcessCheckBox.IsChecked ?? true;
            _config.DebounceDelayMs = (int)(DebounceSlider.Value * 1000);

            // Save config
            ConfigService.Save(_config);

            // Handle auto-start registry
            UpdateAutoStart(_config.AutoStart);

            Logger.Info("Settings saved successfully.");
            DialogResult = true;
            Close();
        }

        private void UpdateAutoStart(bool enable)
        {
            const string keyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
            const string valueName = "MotWatcher";

            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(keyPath, true))
                {
                    if (key == null)
                    {
                        Logger.Error("Unable to open registry key for auto-start.");
                        return;
                    }

                    if (enable)
                    {
                        var exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName;
                        if (!string.IsNullOrEmpty(exePath))
                        {
                            key.SetValue(valueName, $"\"{exePath}\"");
                            Logger.Info("Auto-start enabled in registry.");
                        }
                    }
                    else
                    {
                        key.DeleteValue(valueName, false);
                        Logger.Info("Auto-start disabled in registry.");
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to update auto-start registry: {ex.Message}");
                MessageBox.Show(
                    $"Failed to update auto-start setting:\n{ex.Message}",
                    "Registry Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        }

        private void Cancel_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }
    }

    // Simple input dialog for adding file types
    public class InputDialog : Window
    {
        private readonly System.Windows.Controls.TextBox _textBox;

        public string Result { get; private set; } = string.Empty;

        public InputDialog(string title, string prompt)
        {
            Title = title;
            Width = 400;
            Height = 150;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            ShowInTaskbar = false;

            var grid = new Grid { Margin = new Thickness(10) };
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var label = new System.Windows.Controls.Label { Content = prompt };
            Grid.SetRow(label, 0);
            grid.Children.Add(label);

            _textBox = new System.Windows.Controls.TextBox { Margin = new Thickness(0, 5, 0, 10) };
            Grid.SetRow(_textBox, 1);
            grid.Children.Add(_textBox);

            var buttonPanel = new StackPanel
            {
                Orientation = System.Windows.Controls.Orientation.Horizontal,
                HorizontalAlignment = System.Windows.HorizontalAlignment.Right
            };

            var okButton = new System.Windows.Controls.Button
            {
                Content = "OK",
                IsDefault = true,
                MinWidth = 80,
                Margin = new Thickness(0, 0, 5, 0)
            };
            okButton.Click += (s, e) => { Result = _textBox.Text; DialogResult = true; Close(); };
            buttonPanel.Children.Add(okButton);

            var cancelButton = new System.Windows.Controls.Button
            {
                Content = "Cancel",
                IsCancel = true,
                MinWidth = 80
            };
            cancelButton.Click += (s, e) => { DialogResult = false; Close(); };
            buttonPanel.Children.Add(cancelButton);

            Grid.SetRow(buttonPanel, 2);
            grid.Children.Add(buttonPanel);

            Content = grid;

            Loaded += (s, e) => _textBox.Focus();
        }
    }

    // Edit directory dialog
    public class EditDirectoryDialog : Window
    {
        private readonly WatchedDirectory _directory;
        private readonly System.Windows.Controls.ComboBox _minZoneComboBox;
        private readonly System.Windows.Controls.ComboBox _targetZoneComboBox;
        private readonly System.Windows.Controls.ListBox _excludePatternsList;

        public EditDirectoryDialog(WatchedDirectory directory)
        {
            _directory = directory;

            Title = "Edit Directory Settings";
            Width = 500;
            Height = 450;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            ShowInTaskbar = false;

            var grid = new Grid { Margin = new Thickness(15) };
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Path
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Min zone
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Target zone
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Exclude patterns
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Buttons

            // Path (read-only)
            var pathLabel = new System.Windows.Controls.Label
            {
                Content = $"Path: {directory.Path}",
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 0, 0, 10)
            };
            Grid.SetRow(pathLabel, 0);
            grid.Children.Add(pathLabel);

            // Minimum Zone ID threshold
            var minZonePanel = new StackPanel { Margin = new Thickness(0, 0, 0, 10) };
            minZonePanel.Children.Add(new System.Windows.Controls.Label { Content = "Minimum Zone ID to process:" });

            _minZoneComboBox = new System.Windows.Controls.ComboBox { SelectedIndex = 0 };
            _minZoneComboBox.Items.Add(new ComboBoxItem { Content = "Any Zone", Tag = (int?)null });
            _minZoneComboBox.Items.Add(new ComboBoxItem { Content = "1+ (Intranet or higher)", Tag = 1 });
            _minZoneComboBox.Items.Add(new ComboBoxItem { Content = "2+ (Trusted or higher)", Tag = 2 });
            _minZoneComboBox.Items.Add(new ComboBoxItem { Content = "3+ (Internet only)", Tag = 3 });

            foreach (ComboBoxItem item in _minZoneComboBox.Items)
            {
                if (Equals(item.Tag, directory.MinZoneId))
                {
                    _minZoneComboBox.SelectedItem = item;
                    break;
                }
            }

            minZonePanel.Children.Add(_minZoneComboBox);
            Grid.SetRow(minZonePanel, 1);
            grid.Children.Add(minZonePanel);

            // Target Zone ID
            var targetZonePanel = new StackPanel { Margin = new Thickness(0, 0, 0, 10) };
            var targetLabel = new System.Windows.Controls.Label { Content = "Reassign files to this zone:" };
            targetZonePanel.Children.Add(targetLabel);

            _targetZoneComboBox = new System.Windows.Controls.ComboBox { SelectedIndex = 0 };
            _targetZoneComboBox.Items.Add(new ComboBoxItem { Content = "Remove entirely (NOT recommended)", Tag = (int?)null, Foreground = System.Windows.Media.Brushes.Red });
            _targetZoneComboBox.Items.Add(new ComboBoxItem { Content = "0 - Local Machine (high trust)", Tag = 0 });
            _targetZoneComboBox.Items.Add(new ComboBoxItem { Content = "1 - Local Intranet", Tag = 1 });
            _targetZoneComboBox.Items.Add(new ComboBoxItem { Content = "2 - Trusted Sites (recommended)", Tag = 2, FontWeight = FontWeights.Bold });
            _targetZoneComboBox.Items.Add(new ComboBoxItem { Content = "3 - Internet (no change)", Tag = 3 });

            foreach (ComboBoxItem item in _targetZoneComboBox.Items)
            {
                if (Equals(item.Tag, directory.TargetZoneId))
                {
                    _targetZoneComboBox.SelectedItem = item;
                    break;
                }
            }

            // Auto-adjust target zone when minimum zone changes
            _minZoneComboBox.SelectionChanged += (s, e) =>
            {
                var selectedMin = (_minZoneComboBox.SelectedItem as ComboBoxItem)?.Tag as int?;
                int? suggestedTarget = null;

                // Logic: MinZone 3+ → Target 2, MinZone 2+ → Target 1, MinZone 1+ → Target 0
                if (selectedMin.HasValue)
                {
                    suggestedTarget = selectedMin.Value - 1;
                    if (suggestedTarget < 0) suggestedTarget = 0;
                }
                else
                {
                    suggestedTarget = 2; // Default to Trusted Sites for "Any Zone"
                }

                // Select the suggested target
                foreach (ComboBoxItem item in _targetZoneComboBox.Items)
                {
                    if (Equals(item.Tag, suggestedTarget))
                    {
                        _targetZoneComboBox.SelectedItem = item;
                        break;
                    }
                }
            };

            targetZonePanel.Children.Add(_targetZoneComboBox);
            Grid.SetRow(targetZonePanel, 2);
            grid.Children.Add(targetZonePanel);

            // Exclude Patterns
            var excludeGroup = new System.Windows.Controls.GroupBox
            {
                Header = "Exclude Patterns (e.g., *.part, *.tmp, *.7z.*)",
                Margin = new Thickness(0, 0, 0, 10)
            };

            var excludeGrid = new Grid();
            excludeGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            excludeGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            _excludePatternsList = new System.Windows.Controls.ListBox { Height = 100, Margin = new Thickness(5) };
            foreach (var pattern in directory.ExcludePatterns)
            {
                _excludePatternsList.Items.Add(pattern);
            }
            Grid.SetColumn(_excludePatternsList, 0);
            excludeGrid.Children.Add(_excludePatternsList);

            var excludeButtons = new StackPanel { Margin = new Thickness(5) };
            var addExcludeBtn = new System.Windows.Controls.Button { Content = "Add...", Width = 80, Margin = new Thickness(0, 0, 0, 5) };
            addExcludeBtn.Click += AddExcludePattern_Click;
            var removeExcludeBtn = new System.Windows.Controls.Button { Content = "Remove", Width = 80 };
            removeExcludeBtn.Click += RemoveExcludePattern_Click;
            excludeButtons.Children.Add(addExcludeBtn);
            excludeButtons.Children.Add(removeExcludeBtn);
            Grid.SetColumn(excludeButtons, 1);
            excludeGrid.Children.Add(excludeButtons);

            excludeGroup.Content = excludeGrid;
            Grid.SetRow(excludeGroup, 3);
            grid.Children.Add(excludeGroup);

            // Buttons
            var buttonPanel = new StackPanel
            {
                Orientation = System.Windows.Controls.Orientation.Horizontal,
                HorizontalAlignment = System.Windows.HorizontalAlignment.Right
            };

            var okButton = new System.Windows.Controls.Button
            {
                Content = "OK",
                IsDefault = true,
                MinWidth = 80,
                Margin = new Thickness(0, 0, 5, 0)
            };
            okButton.Click += OkButton_Click;
            buttonPanel.Children.Add(okButton);

            var cancelButton = new System.Windows.Controls.Button
            {
                Content = "Cancel",
                IsCancel = true,
                MinWidth = 80
            };
            cancelButton.Click += (s, e) => { DialogResult = false; Close(); };
            buttonPanel.Children.Add(cancelButton);

            Grid.SetRow(buttonPanel, 4);
            grid.Children.Add(buttonPanel);

            Content = grid;
        }

        private void AddExcludePattern_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new InputDialog("Add Exclude Pattern", "Enter pattern (e.g., *.part, *.tmp, *.7z.*):");
            if (dialog.ShowDialog() == true && !string.IsNullOrWhiteSpace(dialog.Result))
            {
                _excludePatternsList.Items.Add(dialog.Result.Trim());
            }
        }

        private void RemoveExcludePattern_Click(object sender, RoutedEventArgs e)
        {
            if (_excludePatternsList.SelectedItem != null)
            {
                _excludePatternsList.Items.Remove(_excludePatternsList.SelectedItem);
            }
        }

        private void OkButton_Click(object sender, RoutedEventArgs e)
        {
            // Save minimum zone
            var selectedMinItem = _minZoneComboBox.SelectedItem as ComboBoxItem;
            if (selectedMinItem != null)
            {
                _directory.MinZoneId = selectedMinItem.Tag as int?;
            }

            // Save target zone
            var selectedTargetItem = _targetZoneComboBox.SelectedItem as ComboBoxItem;
            if (selectedTargetItem != null)
            {
                _directory.TargetZoneId = selectedTargetItem.Tag as int?;
            }

            // Save exclude patterns
            _directory.ExcludePatterns.Clear();
            foreach (var item in _excludePatternsList.Items)
            {
                if (item is string pattern && !string.IsNullOrWhiteSpace(pattern))
                {
                    _directory.ExcludePatterns.Add(pattern);
                }
            }

            DialogResult = true;
            Close();
        }
    }
}
