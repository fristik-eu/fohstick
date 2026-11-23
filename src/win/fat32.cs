// FOHstick – FAT32 formatter for large drives. (c) 2026 fristik.eu
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class Fat32Fmt {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(SafeFileHandle h, uint code, IntPtr inBuf, uint inSize, IntPtr outBuf, uint outSize, out uint ret, IntPtr ov);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetFilePointerEx(SafeFileHandle h, long dist, out long newPos, uint method);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteFile(SafeFileHandle h, byte[] buf, uint n, out uint written, IntPtr ov);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool FlushFileBuffers(SafeFileHandle h);
    const uint GENERIC_READ = 0x80000000, GENERIC_WRITE = 0x40000000, SHARE_RW = 3, OPEN_EXISTING = 3;
    const uint FSCTL_LOCK = 0x00090018, FSCTL_UNLOCK = 0x0009001C, FSCTL_DISMOUNT = 0x00090020;
    static void Ioctl(SafeFileHandle h, uint code, string what) {
        uint r;
        if (!DeviceIoControl(h, code, IntPtr.Zero, 0, IntPtr.Zero, 0, out r, IntPtr.Zero))
            throw new Exception(what + " (error " + Marshal.GetLastWin32Error() + ")");
    }
    static void W(SafeFileHandle h, long sector, int bps, byte[] data) {
        long np;
        if (!SetFilePointerEx(h, sector * bps, out np, 0)) throw new Exception("Seek failed (error " + Marshal.GetLastWin32Error() + ")");
        uint wr;
        if (!WriteFile(h, data, (uint)data.Length, out wr, IntPtr.Zero) || wr != data.Length)
            throw new Exception("Write failed (error " + Marshal.GetLastWin32Error() + ")");
    }
    static void U16(byte[] b, int o, int v) { b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); }
    static void U32(byte[] b, int o, uint v) { b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); b[o + 2] = (byte)(v >> 16); b[o + 3] = (byte)(v >> 24); }
    static byte[] A(string s) { return System.Text.Encoding.ASCII.GetBytes(s); }

    // Returns cluster count; layout: [reserved][FAT1][FAT2][data...], root = cluster 2
    public static uint Plan(long totalSectors, int bps, int spc, out uint fatSz) {
        if (totalSectors > 0xFFFFFFFFL) throw new Exception("Partition too large for FAT32.");
        if (spc < 1 || spc > 128) throw new Exception("Invalid cluster size.");
        uint total = (uint)totalSectors, reserved = 32, fats = 2;
        ulong num = 4UL * (total - reserved);
        ulong den = (ulong)spc * (ulong)bps + 4UL * fats;
        fatSz = (uint)(num / den + 1);
        uint dataSec = total - reserved - fats * fatSz;
        uint clusters = dataSec / (uint)spc;
        if (clusters < 65525) throw new Exception("Drive too small for FAT32 with this cluster size.");
        if (clusters >= 0x0FFFFFF5) throw new Exception("Drive too large for FAT32 with this cluster size.");
        return clusters;
    }

    public static string Format(string vol, long hidden, long totalSectors, int bps, int spc, string label) {
        uint fatSz;
        uint clusters = Plan(totalSectors, bps, spc, out fatSz);
        uint total = (uint)totalSectors, reserved = 32, fats = 2;
        string lab = (label == null ? "" : label.ToUpperInvariant());
        if (lab.Length > 11) lab = lab.Substring(0, 11);
        if (lab.Trim().Length == 0) lab = "NO NAME";
        lab = lab.PadRight(11);
        using (SafeFileHandle h = CreateFile(vol, GENERIC_READ | GENERIC_WRITE, SHARE_RW, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero)) {
            if (h.IsInvalid) throw new Exception("Cannot open drive (error " + Marshal.GetLastWin32Error() + ")");
            Ioctl(h, FSCTL_LOCK, "Cannot lock drive – close windows and apps using it");
            Ioctl(h, FSCTL_DISMOUNT, "Cannot dismount drive");
            long sysSectors = (long)reserved + (long)fats * fatSz + spc;
            int chunk = Math.Max(1, (1024 * 1024) / bps);
            byte[] zero = new byte[chunk * bps];
            for (long s = 0; s < sysSectors; s += chunk) {
                long n = Math.Min(chunk, sysSectors - s);
                W(h, s, bps, n == chunk ? zero : new byte[n * bps]);
            }
            byte[] bs = BootSector(bps, spc, reserved, fats, hidden, total, fatSz, lab);
            byte[] fi = new byte[bps];
            U32(fi, 0, 0x41615252); U32(fi, 484, 0x61417272); U32(fi, 488, clusters - 1); U32(fi, 492, 3); U32(fi, 508, 0xAA550000);
            W(h, 0, bps, bs); W(h, 1, bps, fi); W(h, 6, bps, bs); W(h, 7, bps, fi);
            byte[] fat = new byte[bps];
            U32(fat, 0, 0x0FFFFFF8); U32(fat, 4, 0x0FFFFFFF); U32(fat, 8, 0x0FFFFFFF);
            for (uint i = 0; i < fats; i++) W(h, reserved + i * fatSz, bps, fat);
            byte[] root = new byte[bps];
            Array.Copy(A(lab), 0, root, 0, 11); root[11] = 0x08;
            W(h, reserved + fats * fatSz, bps, root);
            FlushFileBuffers(h);
            uint r;
            DeviceIoControl(h, FSCTL_UNLOCK, IntPtr.Zero, 0, IntPtr.Zero, 0, out r, IntPtr.Zero);
        }
        return clusters.ToString();
    }

    public static byte[] BootSector(int bps, int spc, uint reserved, uint fats, long hidden, uint total, uint fatSz, string lab) {
        byte[] bs = new byte[bps];
        bs[0] = 0xEB; bs[1] = 0x58; bs[2] = 0x90;
        Array.Copy(A("MSWIN4.1"), 0, bs, 3, 8);
        U16(bs, 11, bps); bs[13] = (byte)spc; U16(bs, 14, (int)reserved); bs[16] = (byte)fats;
        bs[21] = 0xF8; U16(bs, 24, 63); U16(bs, 26, 255);
        U32(bs, 28, (uint)hidden); U32(bs, 32, total); U32(bs, 36, fatSz);
        U32(bs, 44, 2); U16(bs, 48, 1); U16(bs, 50, 6);
        bs[64] = 0x80; bs[66] = 0x29; U32(bs, 67, (uint)DateTime.Now.Ticks);
        Array.Copy(A(lab), 0, bs, 71, 11); Array.Copy(A("FAT32   "), 0, bs, 82, 8);
        bs[510] = 0x55; bs[511] = 0xAA;
        return bs;
    }
}
