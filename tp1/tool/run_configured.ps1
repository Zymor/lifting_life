param(
  [ValidateSet('development', 'staging', 'production')]
  [string]$Environment = 'development',
  [string]$Device = 'windows'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot "config/$Environment.json"
if (!(Test-Path -LiteralPath $configPath)) {
  throw "Missing config/$Environment.json. Copy its .example.json file and enter your existing Supabase project URL and PUBLIC key. No backend is configured yet."
}
$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
if ($config.APP_ENV -ne $Environment) { throw 'Configuration environment does not match the selected environment.' }
$projectUri = $null
if (![Uri]::TryCreate($config.SUPABASE_URL, [UriKind]::Absolute, [ref]$projectUri) -or
    $projectUri.Scheme -ne 'https' -or !$projectUri.Host -or
    $projectUri.UserInfo -or $projectUri.Query -or $projectUri.Fragment -or
    $projectUri.AbsolutePath -ne '/') { throw 'Enter a valid HTTPS Supabase project base URL.' }
$publicKey = $config.SUPABASE_PUBLISHABLE_KEY
if (!$publicKey) { $publicKey = $config.SUPABASE_ANON_KEY }
if (!$publicKey -or $publicKey.StartsWith('sb_secret_')) { throw 'A public publishable or anon key is required. Never use a secret key.' }
if (!$publicKey.StartsWith('sb_publishable_')) {
  try {
    $parts = $publicKey.Split('.')
    if ($parts.Count -ne 3) { throw 'Invalid JWT' }
    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    $payload = $payload.PadRight($payload.Length + ((4 - $payload.Length % 4) % 4), '=')
    $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
    if ($claims.role -ne 'anon') { throw 'Not an anon key' }
  } catch { throw 'Client key rejected. Use a publishable key or a legacy JWT with role anon.' }
}
Push-Location -LiteralPath $projectRoot
try {
  & flutter run -d $Device "--dart-define-from-file=$configPath"
  if ($LASTEXITCODE -ne 0) { throw 'Flutter run failed.' }
} finally { Pop-Location }
