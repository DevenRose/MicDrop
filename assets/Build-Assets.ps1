<#
.SYNOPSIS
  Generate MicDrop logo assets from logo-source.png:
    logo-banner.png  - wide hero (README header / social preview)
    logo.png/512/256 - square head-crop (app icon / GitHub avatar)
    favicon-32/16.png
  Crop region for the square is parameterized so framing is easy to tweak.
#>
[CmdletBinding()]
param(
    [int]$CropX = 880, [int]$CropY = 20, [int]$CropW = 600, [int]$CropH = 600
)
Add-Type -AssemblyName System.Drawing

$src = Join-Path $PSScriptRoot 'logo-source.png'
$img = [System.Drawing.Image]::FromFile($src)

function Save-Resized([System.Drawing.Image]$source, [int]$w, [int]$h, [string]$path, [System.Drawing.Rectangle]$srcRect) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $destRect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    if ($srcRect) { $g.DrawImage($source, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel) }
    else { $g.DrawImage($source, $destRect) }
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "Wrote $(Split-Path $path -Leaf) (${w}x${h})"
}

# wide banner: full image scaled to 1280 wide
$bw = 1280; $bh = [int]($img.Height * $bw / $img.Width)
Save-Resized $img $bw $bh (Join-Path $PSScriptRoot 'logo-banner.png')

# square head-crop
$crop = New-Object System.Drawing.Rectangle $CropX, $CropY, $CropW, $CropH
Save-Resized $img 1024 1024 (Join-Path $PSScriptRoot 'logo.png') $crop
Save-Resized $img 512  512  (Join-Path $PSScriptRoot 'logo-512.png') $crop
Save-Resized $img 256  256  (Join-Path $PSScriptRoot 'logo-256.png') $crop
Save-Resized $img 32   32   (Join-Path $PSScriptRoot 'favicon-32.png') $crop
Save-Resized $img 16   16   (Join-Path $PSScriptRoot 'favicon-16.png') $crop

$img.Dispose()
