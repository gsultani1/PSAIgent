# ===== VisionTools.Tests.ps1 =====
# Critical path 5: image → model

BeforeAll {
    . "$PSScriptRoot\_Bootstrap.ps1" -SkipHeartbeat -SkipAppBuilder
}

AfterAll {
    Remove-TestTempRoot
}

Describe 'VisionTools — Offline' {

    Context 'Test-VisionSupport' {
        It 'Returns true for gpt-4o' {
            Test-VisionSupport -Provider 'openai' -Model 'gpt-4o' | Should -BeTrue
        }

        It 'Returns true for llava' {
            Test-VisionSupport -Provider 'ollama' -Model 'llava' | Should -BeTrue
        }

        It 'Returns true for claude-sonnet-4-5-20250929' {
            Test-VisionSupport -Provider 'anthropic' -Model 'claude-sonnet-4-5-20250929' | Should -BeTrue
        }

        It 'Returns false for gpt-3.5-turbo' {
            Test-VisionSupport -Provider 'openai' -Model 'gpt-3.5-turbo' | Should -BeFalse
        }

        It 'Handles partial match for llava:13b-v1.6' {
            Test-VisionSupport -Provider 'ollama' -Model 'llava:13b-v1.6' | Should -BeTrue
        }

        It 'Handles partial match for llama3.2-vision:11b' {
            Test-VisionSupport -Provider 'ollama' -Model 'llama3.2-vision:11b' | Should -BeTrue
        }
    }

    Context 'ConvertTo-ImageBase64' {
        BeforeAll {
            # Create a minimal 1x1 red PNG programmatically
            Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
            $script:TestPng = Join-Path $global:TestTempRoot 'test_image.png'
            $bmp = New-Object System.Drawing.Bitmap(1, 1)
            $bmp.SetPixel(0, 0, [System.Drawing.Color]::Red)
            $bmp.Save($script:TestPng, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()

            $script:TestJpg = Join-Path $global:TestTempRoot 'test_image.jpg'
            $bmp2 = New-Object System.Drawing.Bitmap(1, 1)
            $bmp2.SetPixel(0, 0, [System.Drawing.Color]::Blue)
            $bmp2.Save($script:TestJpg, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $bmp2.Dispose()
        }

        It 'Encodes a PNG to base64 successfully' {
            $result = ConvertTo-ImageBase64 -Path $script:TestPng
            $result.Success | Should -BeTrue
            $result.Base64 | Should -Not -BeNullOrEmpty
            $result.MediaType | Should -Be 'image/png'
            $result.SizeKB | Should -BeGreaterThan 0
        }

        It 'Encodes a JPG to base64 with correct media type' {
            $result = ConvertTo-ImageBase64 -Path $script:TestJpg
            $result.Success | Should -BeTrue
            $result.MediaType | Should -Be 'image/jpeg'
        }

        It 'Fails for unsupported extension' {
            $tiffPath = Join-Path $global:TestTempRoot 'fake.tiff'
            'not an image' | Set-Content $tiffPath
            $result = ConvertTo-ImageBase64 -Path $tiffPath
            $result.Success | Should -BeFalse
            $result.Output | Should -Match 'Unsupported'
        }

        It 'Fails for missing file' {
            $result = ConvertTo-ImageBase64 -Path 'C:\nonexistent\image.png'
            $result.Success | Should -BeFalse
            $result.Output | Should -Match 'not found'
        }
    }

    Context 'New-VisionMessage' {
        BeforeAll {
            $script:FakeBase64 = [Convert]::ToBase64String([byte[]](0..15))
        }

        It 'Builds OpenAI format with image_url and text elements' {
            $msg = New-VisionMessage -Base64 $script:FakeBase64 -MediaType 'image/png' -Prompt 'Describe this' -Format 'openai'
            $msg.Count | Should -Be 2
            $msg[0].type | Should -Be 'image_url'
            $msg[0].image_url.url | Should -Match '^data:image/png;base64,'
            $msg[1].type | Should -Be 'text'
            $msg[1].text | Should -Be 'Describe this'
        }

        It 'Builds Anthropic format with image source block' {
            $msg = New-VisionMessage -Base64 $script:FakeBase64 -MediaType 'image/png' -Prompt 'Analyze' -Format 'anthropic'
            $msg.Count | Should -Be 2
            $msg[0].type | Should -Be 'image'
            $msg[0].source.type | Should -Be 'base64'
            $msg[0].source.media_type | Should -Be 'image/png'
            $msg[0].source.data | Should -Be $script:FakeBase64
            $msg[1].type | Should -Be 'text'
        }
    }

    Context 'Resize-ImageBitmap' {
        It 'Leaves small images unchanged' {
            $bmp = New-Object System.Drawing.Bitmap(100, 100)
            $result = Resize-ImageBitmap -Bitmap $bmp -MaxEdge 2048
            $result.Width | Should -Be 100
            $result.Height | Should -Be 100
            $result.Dispose()
        }

        It 'Resizes large images to MaxEdge on longest side' {
            $bmp = New-Object System.Drawing.Bitmap(4000, 3000)
            $result = Resize-ImageBitmap -Bitmap $bmp -MaxEdge 2048
            $result.Width | Should -BeLessOrEqual 2048
            $result.Height | Should -BeLessOrEqual 2048
            [math]::Max($result.Width, $result.Height) | Should -Be 2048
            $result.Dispose()
        }

        It 'Maintains aspect ratio' {
            $bmp = New-Object System.Drawing.Bitmap(4000, 2000)
            $result = Resize-ImageBitmap -Bitmap $bmp -MaxEdge 2048
            $ratio = $result.Width / $result.Height
            [math]::Round($ratio, 1) | Should -Be 2.0
            $result.Dispose()
        }
    }

    Context 'Capture-Screenshot' {
        It 'Captures a screenshot on Windows with a display' -Skip:(-not [System.Environment]::OSVersion.Platform.ToString().StartsWith('Win')) {
            $result = Capture-Screenshot
            $result.Success | Should -BeTrue
            $result.Path | Should -Not -BeNullOrEmpty
            Test-Path $result.Path | Should -BeTrue
            $result.Width | Should -BeGreaterThan 0
            $result.Height | Should -BeGreaterThan 0
            Remove-Item $result.Path -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'VisionTools — Live' -Tag 'Live' {

    Context 'Send-ImageToAI' {
        BeforeAll {
            # Create a test image
            Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
            $script:LiveTestPng = Join-Path $global:TestTempRoot 'live_test.png'
            $bmp = New-Object System.Drawing.Bitmap(50, 50)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.Clear([System.Drawing.Color]::Red)
            $g.Dispose()
            $bmp.Save($script:LiveTestPng, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()

            # Check if any vision-capable provider is configured
            $script:HasVisionProvider = $false
            foreach ($pName in @('anthropic', 'openai', 'ollama')) {
                $cfg = $global:ChatProviders[$pName]
                if ($cfg) {
                    $model = $cfg.DefaultModel
                    if (Test-VisionSupport -Provider $pName -Model $model) {
                        $script:VisionProvider = $pName
                        $script:VisionModel = $model
                        $script:HasVisionProvider = $true
                        break
                    }
                }
            }
        }

        It 'Sends an image and receives a response' -Skip:(-not $script:HasVisionProvider) {
            $result = Send-ImageToAI -ImagePath $script:LiveTestPng -Prompt 'What color is this image?' -Provider $script:VisionProvider -Model $script:VisionModel
            $result.Success | Should -BeTrue
            $result.Output | Should -Not -BeNullOrEmpty
        }
    }
}
