using System.Drawing;
using System.Reflection;
using System.Windows;
using System.Windows.Forms;
using MotW.Shared.Models;
using MotW.Shared.Services;
using MotW.Shared.Utils;
using MotWatcher.Services;
using Application = System.Windows.Application;

namespace MotWatcher;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    private NotifyIcon? _notifyIcon;
    private FileWatcherService? _watcherService;
    private Models.WatcherConfig? _config;
    private WatcherStatistics? _statistics;
    private Icon? _iconRunning;
    private Icon? _iconStopped;

    private void Application_Startup(object sender, StartupEventArgs e)
    {
        Logger.Info("MotWatcher starting...");

        // Load configuration and statistics
        _config = ConfigService.Load();
        _statistics = StatisticsService.Load();

        // Load custom icons from embedded resources
        _iconStopped = LoadIconFromResource("tray-stopped.ico");
        _iconRunning = LoadIconFromResource("tray-running.ico");

        // Create system tray icon
        _notifyIcon = new NotifyIcon
        {
            Icon = _iconStopped ?? SystemIcons.Shield, // Use custom icon or fallback to system icon
            Visible = true,
            Text = "MotW Watcher - Not Running"
        };

        // Create context menu
        var contextMenu = new ContextMenuStrip();

        var startStopItem = new ToolStripMenuItem("Start Watching")
        {
            Name = "StartStop"
        };
        startStopItem.Click += StartStop_Click;
        contextMenu.Items.Add(startStopItem);

        contextMenu.Items.Add(new ToolStripSeparator());

        var statisticsItem = new ToolStripMenuItem("Statistics...");
        statisticsItem.Click += Statistics_Click;
        contextMenu.Items.Add(statisticsItem);

        var settingsItem = new ToolStripMenuItem("Settings...");
        settingsItem.Click += Settings_Click;
        contextMenu.Items.Add(settingsItem);

        var openLogItem = new ToolStripMenuItem("Open Log Folder");
        openLogItem.Click += OpenLog_Click;
        contextMenu.Items.Add(openLogItem);

        var runRulesItem = new ToolStripMenuItem("Run Rules Now...");
        runRulesItem.Click += RunRules_Click;
        contextMenu.Items.Add(runRulesItem);

        contextMenu.Items.Add(new ToolStripSeparator());

        var exitItem = new ToolStripMenuItem("Exit");
        exitItem.Click += Exit_Click;
        contextMenu.Items.Add(exitItem);

        _notifyIcon.ContextMenuStrip = contextMenu;
        _notifyIcon.DoubleClick += NotifyIcon_DoubleClick;

        // Initialize watcher service
        _watcherService = new FileWatcherService(_config);
        _watcherService.FileProcessed += OnFileProcessed;

        // Auto-start watching if configured
        if (_config.StartWatchingOnLaunch)
        {
            StartWatching();
        }

        Logger.Info("MotWatcher initialized.");
    }

    private void StartStop_Click(object? sender, EventArgs e)
    {
        if (_watcherService == null || _notifyIcon == null || _notifyIcon.ContextMenuStrip == null)
            return;

        var menuItem = _notifyIcon.ContextMenuStrip.Items["StartStop"] as ToolStripMenuItem;
        if (menuItem == null)
            return;

        if (menuItem.Text == "Start Watching")
        {
            StartWatching();
        }
        else
        {
            StopWatching();
        }
    }

    private void StartWatching()
    {
        if (_watcherService == null || _notifyIcon == null || _notifyIcon.ContextMenuStrip == null)
            return;

        var menuItem = _notifyIcon.ContextMenuStrip.Items["StartStop"] as ToolStripMenuItem;
        if (menuItem != null)
        {
            _watcherService.Start();
            menuItem.Text = "Stop Watching";
            _notifyIcon.Text = "MotWatcher - Running";
            _notifyIcon.Icon = _iconRunning ?? SystemIcons.Application;
            Logger.Info("Watcher service started.");
        }
    }

    private void StopWatching()
    {
        if (_watcherService == null || _notifyIcon == null || _notifyIcon.ContextMenuStrip == null)
            return;

        var menuItem = _notifyIcon.ContextMenuStrip.Items["StartStop"] as ToolStripMenuItem;
        if (menuItem != null)
        {
            _watcherService.Stop();
            menuItem.Text = "Start Watching";
            _notifyIcon.Text = "MotWatcher - Not Running";
            _notifyIcon.Icon = _iconStopped ?? SystemIcons.Shield;
            Logger.Info("Watcher service stopped.");
        }
    }

    private void Statistics_Click(object? sender, EventArgs e)
    {
        if (_statistics == null)
            return;

        var statisticsWindow = new StatisticsWindow(_statistics)
        {
            Owner = null
        };

        statisticsWindow.ShowDialog();

        // Reload statistics in case they were reset
        _statistics = StatisticsService.Load();
    }

    private void Settings_Click(object? sender, EventArgs e)
    {
        if (_config == null)
            return;

        var settingsWindow = new SettingsWindow(_config)
        {
            Owner = null
        };

        if (settingsWindow.ShowDialog() == true)
        {
            // Reload config
            _config = ConfigService.Load();

            // Restart watcher service if it was running
            if (_watcherService != null)
            {
                var wasRunning = _notifyIcon?.ContextMenuStrip?.Items["StartStop"] is ToolStripMenuItem item &&
                                 item.Text == "Stop Watching";

                if (wasRunning)
                {
                    StopWatching();
                    _watcherService = new FileWatcherService(_config);
                    _watcherService.FileProcessed += OnFileProcessed;
                    StartWatching();
                    Logger.Info("Watcher service restarted with new configuration.");
                }
                else
                {
                    // Just reinitialize without starting
                    _watcherService.Dispose();
                    _watcherService = new FileWatcherService(_config);
                    _watcherService.FileProcessed += OnFileProcessed;
                    Logger.Info("Watcher service reloaded with new configuration.");
                }
            }
        }
    }

    private void OpenLog_Click(object? sender, EventArgs e)
    {
        try
        {
            var folder = Logger.LogFolder;
            System.IO.Directory.CreateDirectory(folder);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = folder,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to open log folder: {ex.Message}");
            System.Windows.MessageBox.Show(
                $"Unable to open log folder: {ex.Message}",
                "Error",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
    }

    private async void RunRules_Click(object? sender, EventArgs e)
    {
        try
        {
            Logger.Info("Manual 'Run Rules Now' triggered by user");

            var result = System.Windows.MessageBox.Show(
                "This will scan all configured directories and apply zone rules to existing files.\n\n" +
                "Files will be processed based on your current settings:\n" +
                "- Watched directories and their rules\n" +
                "- Minimum zone ID thresholds\n" +
                "- Target zone assignments\n\n" +
                "Continue?",
                "Run Rules Now",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (result != MessageBoxResult.Yes)
            {
                Logger.Info("User cancelled manual rule execution");
                return;
            }

            await Task.Run(() => _watcherService?.RunRulesOnExistingFiles());

            _notifyIcon?.ShowBalloonTip(
                3000,
                "Rules Executed",
                "All configured directories have been processed.",
                ToolTipIcon.Info);

            Logger.Info("Manual rule execution completed");
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to run rules: {ex.Message}");
            System.Windows.MessageBox.Show(
                $"Failed to run rules: {ex.Message}",
                "Error",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
    }

    private void Exit_Click(object? sender, EventArgs e)
    {
        Logger.Info("Exit requested by user.");
        Shutdown();
    }

    private void NotifyIcon_DoubleClick(object? sender, EventArgs e)
    {
        Settings_Click(sender, e);
    }

    private void OnFileProcessed(object? sender, FileProcessedEventArgs e)
    {
        // Record statistics for successful operations
        if (e.Success && _statistics != null)
        {
            StatisticsService.RecordFileProcessed(_statistics, e.FilePath, e.FileSize, e.ZoneId);
        }

        // Show notification if enabled
        if (_config?.NotifyOnProcess == true && _notifyIcon != null)
        {
            var fileName = System.IO.Path.GetFileName(e.FilePath);
            var title = e.Success ? "MotW Removed" : "Failed to Remove MotW";
            var message = e.Success
                ? $"Successfully unblocked: {fileName}"
                : $"Failed to unblock {fileName}: {e.Message}";

            // Show balloon tip with 5 second timeout (will auto-dismiss)
            _notifyIcon.ShowBalloonTip(
                5000,
                title,
                message,
                e.Success ? ToolTipIcon.Info : ToolTipIcon.Warning);
        }
    }

    private void Application_Exit(object sender, ExitEventArgs e)
    {
        Logger.Info("MotWatcher shutting down...");

        _watcherService?.Dispose();

        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }

        _iconRunning?.Dispose();
        _iconStopped?.Dispose();

        Logger.Info("MotWatcher shutdown complete.");
    }

    private static Icon? LoadIconFromResource(string resourceName)
    {
        try
        {
            var assembly = Assembly.GetExecutingAssembly();
            using var stream = assembly.GetManifestResourceStream(resourceName);

            if (stream == null)
            {
                Logger.Warn($"Icon resource not found: {resourceName}");
                return null;
            }

            return new Icon(stream);
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to load icon resource '{resourceName}': {ex.Message}");
            return null;
        }
    }
}

