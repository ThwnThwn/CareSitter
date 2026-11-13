using System.Diagnostics;
using System.Net;

namespace CareSitter.Nutrition.Infrastructure;

// Development-only adapter for Windows machines where managed HTTPS stalls.
// Credentials and JSON travel through stdin, never command-line arguments or temporary request files.
public sealed class WindowsGeminiDemoHandler : HttpMessageHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        if (!OperatingSystem.IsWindows()) throw new HttpRequestException("Windows development transport is unavailable.");
        if (request.RequestUri?.Host != "generativelanguage.googleapis.com" || request.RequestUri.Scheme != "https")
            throw new HttpRequestException("Unsupported local-demo endpoint.");
        var start = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "curl.exe"))
        {
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true,
            UseShellExecute = false, CreateNoWindow = true,
            StandardInputEncoding = new System.Text.UTF8Encoding(false),
            StandardOutputEncoding = System.Text.Encoding.UTF8,
            StandardErrorEncoding = System.Text.Encoding.UTF8
        };
        foreach (var value in new[] { "--config", "-", "--silent", "--show-error", "--proto", "=https", "--max-time", "28",
                     "--connect-timeout", "8", "--max-filesize", "65536", "--write-out", "\n%{http_code}", request.RequestUri.AbsoluteUri })
            start.ArgumentList.Add(value);
        using var process = Process.Start(start) ?? throw new HttpRequestException("Local transport could not start.");
        using var cancellation = ct.Register(() => { try { if (!process.HasExited) process.Kill(); } catch (InvalidOperationException) { } });
        var output = process.StandardOutput.ReadToEndAsync(ct);
        var errors = process.StandardError.ReadToEndAsync(ct);
        var lines = new List<string> { $"request = {Quote(request.Method.Method)}" };
        foreach (var header in request.Headers)
            lines.Add($"header = {Quote(header.Key + ": " + string.Join(", ", header.Value))}");
        if (request.Content is not null)
        {
            lines.Add("header = \"Content-Type: application/json\"");
            lines.Add("data-binary = " + Quote(await request.Content.ReadAsStringAsync(ct)));
        }
        await process.StandardInput.WriteAsync(string.Join('\n', lines));
        process.StandardInput.Close();
        await process.WaitForExitAsync(ct);
        var body = await output;
        _ = await errors;
        if (process.ExitCode != 0) throw new HttpRequestException("Local HTTPS transport failed.");
        var separator = body.LastIndexOf('\n');
        if (separator < 0 || !int.TryParse(body[(separator + 1)..], out var status)) throw new HttpRequestException("Invalid transport response.");
        return new((HttpStatusCode)status) { Content = new StringContent(body[..separator]), RequestMessage = request };
    }

    private static string Quote(string value) => '"' + value.Replace("\\", "\\\\").Replace("\"", "\\\"")
        .Replace("\r", "\\r").Replace("\n", "\\n") + '"';
}
