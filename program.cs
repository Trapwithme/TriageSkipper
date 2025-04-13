using System;
using System.IO;
using System.Linq;
using System.Management;
using System.Windows.Forms;
using Microsoft.Win32;

namespace X7K9P2M
{
    /// <summary>
    /// Main program for detecting virtual machine (VM) environments using hardware and wallpaper checks.
    /// Displays a warning and exits if a VM is detected.
    /// </summary>
    class Program
    {
        private const string MouseID = @"ACPI\PNP0F13\4&22F5829E&0";
        private const string MouseName = "PS2/2 Compatible Mouse";

        private const string InputID = @"USB\VID_0627&PID_0001\28754-0000:00:04.0-1";
        private const string InputName = "USB Input Device";

        private const string MonitorID = @"DISPLAY\RHT1234\4&22F5829E&0";
        private const string MonitorName = "Generic PnP Monitor";

        private const string KeyboardID = @"ACPI\PNP0303\4&22F5829E&0";
        private const string KeyboardName = "Standard PS/2 Keyboard";

        private const string CPU = "Intel Core Processor (Broadwell)";

        /// <summary>
        /// Checks keyboard properties via WMI to detect VM-specific identifiers.
        /// </summary>
        /// <returns>(bool: detected, int: match count)</returns>
        private static (bool, int) CheckKeyboard()
        {
            int index = 0;
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT Description, DeviceID FROM Win32_Keyboard"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        string description = obj?["Description"]?.ToString() ?? "";
                        string deviceId = obj?["DeviceID"]?.ToString() ?? "";

                        if (!string.IsNullOrEmpty(deviceId) && deviceId.IndexOf(KeyboardID, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            index++;
                            if (!string.IsNullOrEmpty(description) && description.IndexOf(KeyboardName, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                index++;
                            }
                        }
                    }
                }
            }
            catch
            {
                // Silent error handling
            }

            return (index >= 1, index);
        }

        /// <summary>
        /// Checks mouse properties via WMI to detect VM-specific identifiers.
        /// </summary>
        /// <returns>(bool: detected, int: match count)</returns>
        private static (bool, int) CheckMouse()
        {
            int index = 0;
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT Description, PNPDeviceID FROM Win32_PointingDevice"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        string description = obj?["Description"]?.ToString() ?? "";
                        string pnpDeviceId = obj?["PNPDeviceID"]?.ToString() ?? "";

                        if (!string.IsNullOrEmpty(pnpDeviceId) && pnpDeviceId.IndexOf(MouseID, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            index++;
                            if (!string.IsNullOrEmpty(description) && description.IndexOf(MouseName, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                index++;
                            }
                        }
                    }
                }
            }
            catch
            {
                // Silent error handling
            }

            return (index >= 1, index);
        }

        /// <summary>
        /// Checks input device properties via WMI to detect VM-specific identifiers.
        /// </summary>
        /// <returns>(bool: detected, int: match count)</returns>
        private static (bool, int) CheckInput()
        {
            int index = 0;
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT Description, PNPDeviceID FROM Win32_PointingDevice"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        string description = obj?["Description"]?.ToString() ?? "";
                        string pnpDeviceId = obj?["PNPDeviceID"]?.ToString() ?? "";

                        if (!string.IsNullOrEmpty(pnpDeviceId) && pnpDeviceId.IndexOf(InputID, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            index++;
                            if (!string.IsNullOrEmpty(description) && description.IndexOf(InputName, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                index++;
                            }
                        }
                    }
                }
            }
            catch
            {
                // Silent error handling
            }

            return (index >= 1, index);
        }

        /// <summary>
        /// Checks monitor properties via WMI to detect VM-specific identifiers.
        /// </summary>
        /// <returns>(bool: detected, int: match count)</returns>
        private static (bool, int) CheckMonitor()
        {
            int index = 0;
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT Description, PNPDeviceID FROM Win32_DesktopMonitor"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        string description = obj?["Description"]?.ToString() ?? "";
                        string pnpDeviceId = obj?["PNPDeviceID"]?.ToString() ?? "";

                        if (!string.IsNullOrEmpty(pnpDeviceId) && pnpDeviceId.IndexOf(MonitorID, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            index++;
                            if (!string.IsNullOrEmpty(description) && description.IndexOf(MonitorName, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                index++;
                            }
                        }
                    }
                }
            }
            catch
            {
                // Silent error handling
            }

            return (index >= 1, index);
        }

        /// <summary>
        /// Checks CPU properties via WMI to detect VM-specific identifiers.
        /// </summary>
        /// <returns>(bool: detected, int: match count)</returns>
        private static (bool, int) CheckCPU()
        {
            int index = 0;
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT Name FROM Win32_Processor"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        string name = obj?["Name"]?.ToString() ?? "";
                        if (!string.IsNullOrEmpty(name) && name.IndexOf(CPU, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            index++;
                        }
                    }
                }
            }
            catch
            {
                // Silent error handling
            }

            return (index >= 1, index);
        }

        /// <summary>
        /// Retrieves the current desktop wallpaper path from the registry.
        /// </summary>
        /// <returns>Wallpaper path or empty string if not found.</returns>
        private static string GetWallpaper()
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop"))
                {
                    return key?.GetValue("Wallpaper")?.ToString() ?? "";
                }
            }
            catch
            {
                // Silent error handling
            }

            return "";
        }

        /// <summary>
        /// Encodes a byte array to a Base64 string.
        /// </summary>
        /// <param name="data">Byte array to encode.</param>
        /// <returns>Base64 string or empty string on error.</returns>
        private static string EncodeToBase64(byte[] data)
        {
            try
            {
                return Convert.ToBase64String(data);
            }
            catch
            {
                // Silent error handling
            }

            return "";
        }

        /// <summary>
        /// Reads an image file into a byte array.
        /// </summary>
        /// <param name="filePath">Path to the image file.</param>
        /// <returns>Byte array or empty array on error.</returns>
        private static byte[] ReadImage(string filePath)
        {
            try
            {
                return File.ReadAllBytes(filePath);
            }
            catch
            {
                // Silent error handling
            }

            return new byte[0];
        }

        /// <summary>
        /// Truncates a Base64 string to 64 characters.
        /// </summary>
        /// <param name="base64String">Base64 string to truncate.</param>
        /// <returns>Truncated string.</returns>
        private static string TruncateBase64(string base64String)
        {
            return base64String.Length > 64 ? base64String.Substring(0, 64) : base64String;
        }

        /// <summary>
        /// Performs hardware-based VM detection by aggregating check results.
        /// </summary>
        /// <returns>True if VM is detected (total index >= 5).</returns>
        private static bool Triage()
        {
            var checks = new Func<(bool, int)>[] {
                CheckKeyboard,
                CheckMouse,
                CheckInput,
                CheckMonitor,
                CheckCPU
            };

            int totalIndex = 0;
            foreach (var check in checks)
            {
                var (_, index) = check();
                totalIndex += index;
            }

            return totalIndex >= 5;
        }

        /// <summary>
        /// Performs wallpaper-based VM detection by checking Base64-encoded image prefix.
        /// </summary>
        /// <returns>True if wallpaper matches VM signature.</returns>
        private static bool TriageV2()
        {
            try
            {
                string wallpaperPath = GetWallpaper().Trim();
                if (string.IsNullOrEmpty(wallpaperPath))
                    return false;

                byte[] imageBytes = ReadImage(wallpaperPath);
                if (imageBytes.Length == 0)
                    return false;

                string base64String = EncodeToBase64(imageBytes);
                string truncatedBase64 = TruncateBase64(base64String);

                return truncatedBase64 == "/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAwMDAwMDA0ODg0SExETEhsYFhYYGygd";
            }
            catch
            {
                // Silent error handling
            }

            return false;
        }

        /// <summary>
        /// Runs VM detection and terminates the application if a VM is detected.
        /// </summary>
        private static void RunTriage()
        {
            bool isTriageDetected = Triage();
            bool isTriageV2Detected = TriageV2();

            if (isTriageDetected || isTriageV2Detected)
            {
                MessageBox.Show(
                    "Virtual Machine Detected",
                    "System Check",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning
                );
                Environment.Exit(1);
            }
        }

        /// <summary>
        /// Main entry point for the VM detection program.
        /// </summary>
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            try
            {
                Console.WriteLine("Running VM detection...");
                RunTriage();
                Console.WriteLine("No VM detected, application can proceed.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }
    }
}
