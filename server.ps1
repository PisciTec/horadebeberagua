$listener = New-Object System.Net.HttpListener;
$listener.Prefixes.Add("http://localhost:8000/");
try {
    $listener.Start();
    Write-Output "HTTP Server started on http://localhost:8000/";
    while ($listener.IsListening) {
        $context = $listener.GetContext();
        $req = $context.Request;
        $res = $context.Response;
        
        $path = $req.Url.LocalPath;
        if ($path -eq "/" -or $path -eq "") {
            $path = "/index.html";
        }
        
        # Map request to local folder
        $localPath = Join-Path "C:\Users\ERALDO NICACIO\Desktop\PROJETOS\BEBERAGUA" $path.Substring(1);
        
        if (Test-Path $localPath -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($localPath);
            
            # Set basic MIME types
            if ($localPath.EndsWith(".html")) {
                $res.ContentType = "text/html; charset=utf-8";
            } elseif ($localPath.EndsWith(".css")) {
                $res.ContentType = "text/css; charset=utf-8";
            } elseif ($localPath.EndsWith(".js")) {
                $res.ContentType = "application/javascript; charset=utf-8";
            } elseif ($localPath.EndsWith(".svg")) {
                $res.ContentType = "image/svg+xml";
            } elseif ($localPath.EndsWith(".json")) {
                $res.ContentType = "application/json; charset=utf-8";
            }
            
            $res.ContentLength64 = $bytes.Length;
            $res.OutputStream.Write($bytes, 0, $bytes.Length);
        } else {
            $res.StatusCode = 404;
            $errorMsg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found");
            $res.OutputStream.Write($errorMsg, 0, $errorMsg.Length);
        }
        $res.OutputStream.Close();
    }
} catch {
    Write-Error $_.Exception.Message;
} finally {
    $listener.Stop();
}
