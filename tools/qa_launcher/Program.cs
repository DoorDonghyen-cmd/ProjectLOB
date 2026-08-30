using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("ProjectLoB QA Launcher")]
[assembly: AssemblyDescription("Starts the local ProjectLoB QA dashboard controller")]
[assembly: AssemblyCompany("ProjectLoB")]
[assembly: AssemblyProduct("ProjectLoB QA")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class Program
{
    private const int DefaultPort = 8765;
    private const int DashboardWaitSeconds = 20;

    private sealed class Options
    {
        public int Port = DefaultPort;
        public string GodotPath = "";
        public bool NoBrowser;
        public bool CheckOnly;
        public bool Probe;
        public bool Help;
    }

    private static Process controllerProcess;
    private static bool cancellationRequested;

    private static int Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;
        Console.Title = "ProjectLoB QA Dashboard";

        try
        {
            Options options = ParseOptions(args);
            if (options.Help)
            {
                PrintHelp();
                return 0;
            }

            string controllerPath = FindControllerScript(AppDomain.CurrentDomain.BaseDirectory);
            if (String.IsNullOrEmpty(controllerPath))
            {
                return Fail("tools\\qa_dashboard_controller.ps1 was not found. Keep the EXE inside the ProjectLoB repository.");
            }

            string repoRoot = Directory.GetParent(Path.GetDirectoryName(controllerPath)).FullName;
            string dashboardPath = Path.Combine(repoRoot, "docs", "qa", "dashboard", "index.html");
            string runnerPath = Path.Combine(repoRoot, "tools", "qa_run_playtest.ps1");

            if (!File.Exists(dashboardPath))
            {
                return Fail("Dashboard file was not found: " + dashboardPath);
            }
            if (!File.Exists(runnerPath))
            {
                return Fail("QA runner was not found: " + runnerPath);
            }
            if (!String.IsNullOrWhiteSpace(options.GodotPath) && !File.Exists(options.GodotPath))
            {
                return Fail("The specified Godot executable was not found: " + options.GodotPath);
            }

            Console.WriteLine("ProjectLoB QA Launcher");
            Console.WriteLine("Repository : " + repoRoot);
            Console.WriteLine("Dashboard  : http://127.0.0.1:" + options.Port + "/");

            if (options.CheckOnly)
            {
                Console.WriteLine("Launcher check OK");
                return 0;
            }

            Console.WriteLine("Starting the QA controller...");
            Console.WriteLine("Close this window or press Ctrl+C to stop it.");
            Console.WriteLine();

            string arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File " + Quote(controllerPath)
                + " -Port " + options.Port;
            if (!String.IsNullOrWhiteSpace(options.GodotPath))
            {
                arguments += " -GodotPath " + Quote(options.GodotPath);
            }

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = "powershell.exe";
            startInfo.Arguments = arguments;
            startInfo.WorkingDirectory = repoRoot;
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = false;

            controllerProcess = Process.Start(startInfo);
            if (controllerProcess == null)
            {
                return Fail("PowerShell controller could not be started.");
            }

            Console.CancelKeyPress += OnCancelKeyPress;

            bool ready = WaitForDashboard(controllerProcess, options.Port, DashboardWaitSeconds);
            if (options.Probe)
            {
                Console.WriteLine(ready ? "Live controller probe OK" : "Live controller probe failed");
                cancellationRequested = true;
                StopController();
                controllerProcess.WaitForExit();
                return ready ? 0 : 1;
            }
            if (ready && !options.NoBrowser)
            {
                OpenBrowser("http://127.0.0.1:" + options.Port + "/");
            }
            else if (!ready && !controllerProcess.HasExited)
            {
                Console.WriteLine("Dashboard did not answer within " + DashboardWaitSeconds + " seconds. The controller is still running.");
            }

            controllerProcess.WaitForExit();
            int exitCode = controllerProcess.ExitCode;
            if (cancellationRequested)
            {
                return 0;
            }
            if (exitCode != 0)
            {
                return Fail("QA controller exited with code " + exitCode + ".");
            }
            return 0;
        }
        catch (ArgumentException exception)
        {
            Console.Error.WriteLine("Argument error: " + exception.Message);
            PrintHelp();
            return 2;
        }
        catch (Exception exception)
        {
            return Fail(exception.Message);
        }
    }

    private static Options ParseOptions(string[] args)
    {
        Options options = new Options();
        for (int index = 0; index < args.Length; index++)
        {
            string argument = args[index];
            if (argument == "--help" || argument == "-h" || argument == "/?")
            {
                options.Help = true;
            }
            else if (argument == "--check")
            {
                options.CheckOnly = true;
            }
            else if (argument == "--no-browser")
            {
                options.NoBrowser = true;
            }
            else if (argument == "--probe")
            {
                options.Probe = true;
                options.NoBrowser = true;
            }
            else if (argument == "--port")
            {
                string value = NextValue(args, ref index, argument);
                int port;
                if (!Int32.TryParse(value, out port) || port < 1024 || port > 65535)
                {
                    throw new ArgumentException("--port must be between 1024 and 65535.");
                }
                options.Port = port;
            }
            else if (argument == "--godot")
            {
                options.GodotPath = Path.GetFullPath(NextValue(args, ref index, argument));
            }
            else
            {
                throw new ArgumentException("Unknown option: " + argument);
            }
        }
        return options;
    }

    private static string NextValue(string[] args, ref int index, string option)
    {
        index++;
        if (index >= args.Length || String.IsNullOrWhiteSpace(args[index]))
        {
            throw new ArgumentException(option + " requires a value.");
        }
        return args[index];
    }

    private static string FindControllerScript(string startDirectory)
    {
        DirectoryInfo directory = new DirectoryInfo(Path.GetFullPath(startDirectory));
        for (int depth = 0; directory != null && depth < 8; depth++, directory = directory.Parent)
        {
            string directCandidate = Path.Combine(directory.FullName, "qa_dashboard_controller.ps1");
            if (File.Exists(directCandidate))
            {
                return directCandidate;
            }

            string toolsCandidate = Path.Combine(directory.FullName, "tools", "qa_dashboard_controller.ps1");
            if (File.Exists(toolsCandidate))
            {
                return toolsCandidate;
            }
        }
        return "";
    }

    private static bool WaitForDashboard(Process process, int port, int timeoutSeconds)
    {
        DateTime deadline = DateTime.UtcNow.AddSeconds(timeoutSeconds);
        while (DateTime.UtcNow < deadline)
        {
            if (process.HasExited)
            {
                return false;
            }
            try
            {
                using (TcpClient client = new TcpClient())
                {
                    IAsyncResult result = client.BeginConnect("127.0.0.1", port, null, null);
                    if (result.AsyncWaitHandle.WaitOne(300) && client.Connected)
                    {
                        client.EndConnect(result);
                        return true;
                    }
                }
            }
            catch (SocketException)
            {
            }
            Thread.Sleep(250);
        }
        return false;
    }

    private static void OpenBrowser(string url)
    {
        try
        {
            ProcessStartInfo browser = new ProcessStartInfo();
            browser.FileName = url;
            browser.UseShellExecute = true;
            Process.Start(browser);
        }
        catch (Exception exception)
        {
            Console.WriteLine("Browser could not be opened automatically: " + exception.Message);
            Console.WriteLine("Open manually: " + url);
        }
    }

    private static void OnCancelKeyPress(object sender, ConsoleCancelEventArgs eventArgs)
    {
        eventArgs.Cancel = true;
        cancellationRequested = true;
        StopController();
    }

    private static void StopController()
    {
        try
        {
            if (controllerProcess != null && !controllerProcess.HasExited)
            {
                controllerProcess.Kill();
            }
        }
        catch
        {
        }
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static int Fail(string message)
    {
        Console.Error.WriteLine("ERROR: " + message);
        return 1;
    }

    private static void PrintHelp()
    {
        Console.WriteLine("Usage: ProjectLoB-QA.exe [options]");
        Console.WriteLine("  --check          Validate required project files and exit");
        Console.WriteLine("  --probe          Start the controller, verify localhost, then stop");
        Console.WriteLine("  --no-browser     Do not open the dashboard automatically");
        Console.WriteLine("  --port <number>  Dashboard port (default: 8765)");
        Console.WriteLine("  --godot <path>   Explicit Godot console executable path");
        Console.WriteLine("  --help           Show this help");
    }
}
