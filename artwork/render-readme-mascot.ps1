$ErrorActionPreference = "Stop"

$artwork = $PSScriptRoot
$raeaCommand = Get-Command "raea" -ErrorAction SilentlyContinue
$raea = if ($raeaCommand) { $raeaCommand.Source } else { Join-Path $env:USERPROFILE ".raea\bin\raea.exe" }
$ffmpegCommand = Get-Command "ffmpeg" -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $raea)) {
  throw "RAEA was not found. Install it from https://raea.io/install."
}
if (-not $ffmpegCommand) {
  throw "ffmpeg is required to encode the RAEA renders as README GIFs."
}

$jobs = @(
  @{ Source = "readme-hero.tsx"; Composition = "readme-hero"; Name = "subagents-hero"; Frame = 72; Still = "subagents-hero.png" },
  @{ Source = "axolotl-3d.tsx"; Composition = "axolotl-setup"; Name = "axolotl-setup"; Frame = 24; Still = "media\axolotl-setup-still.png" },
  @{ Source = "axolotl-3d.tsx"; Composition = "axolotl-configure"; Name = "axolotl-configure"; Frame = 24; Still = "media\axolotl-configure-still.png" },
  @{ Source = "axolotl-3d.tsx"; Composition = "axolotl-eval-apis"; Name = "axolotl-eval-apis"; Frame = 24; Still = "media\axolotl-eval-apis-still.png" },
  @{ Source = "axolotl-3d.tsx"; Composition = "axolotl-sessions"; Name = "axolotl-sessions"; Frame = 24; Still = "media\axolotl-sessions-still.png" }
)

$temp = Join-Path $env:TEMP "nodecode-subagents-readme-mascot"
New-Item -ItemType Directory -Force -Path $temp | Out-Null

foreach ($job in $jobs) {
  $source = Join-Path $artwork $job.Source
  $gif = Join-Path $artwork ($job.Name + ".gif")
  $still = Join-Path $artwork $job.Still
  $video = Join-Path $temp ($job.Name + ".mp4")
  $stillDirectory = Split-Path -Parent $still
  New-Item -ItemType Directory -Force -Path $stillDirectory | Out-Null

  & $raea render $source --composition $job.Composition -o $video --quality high
  if ($LASTEXITCODE -ne 0) { throw "RAEA animation render failed for $($job.Name)." }

  & $raea render $source --composition $job.Composition --frame $job.Frame -o $still
  if ($LASTEXITCODE -ne 0) { throw "RAEA static fallback render failed for $($job.Name)." }

  & $ffmpegCommand.Source -y -i $video -filter_complex "fps=12,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" -loop 0 $gif
  if ($LASTEXITCODE -ne 0) { throw "GIF encoding failed for $($job.Name)." }

  Get-Item -LiteralPath $gif, $still | Select-Object FullName, Length
}
