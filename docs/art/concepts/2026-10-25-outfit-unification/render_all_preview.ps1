$ErrorActionPreference='Stop'
$repo='D:\ProjectLoB\worktrees\core-redesign'
$runtime=Join-Path $repo 'qa_runtime\outfit_unification_20261025'
$env:APPDATA=Join-Path $runtime 'Roaming'
$env:LOCALAPPDATA=Join-Path $runtime 'Local'
New-Item -ItemType Directory -Force -Path $runtime,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
$engine='D:\ProjectLoB\.tmp\godot-4.7\Godot_v4.7-stable_win64_console.exe'
$project=(Get-ChildItem -LiteralPath $repo -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'project.godot') } | Select-Object -First 1).FullName
$preview=Join-Path $repo 'docs\art\concepts\2026-10-25-outfit-unification\render_all_preview.gd'
$arguments=@('--path', ('"{0}"' -f $project), '--script',('"{0}"' -f $preview),'--rendering-method','gl_compatibility','--resolution','1280x1050','--position','-2500,-2500')
$p=Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'stdout.log') -RedirectStandardError (Join-Path $runtime 'stderr.log')
if (-not $p.WaitForExit(45000)) { Stop-Process -Id $p.Id; throw 'Preview timed out' }
$p.WaitForExit()
$result=Get-Content -Raw (Join-Path $runtime 'stdout.log')
$errors=Get-Content -Raw (Join-Path $runtime 'stderr.log')
Write-Output $result
if ($errors) { Write-Output $errors }
if (($null -ne $p.ExitCode -and $p.ExitCode -ne 0) -or $errors -match 'SCRIPT ERROR|Parse Error|Assertion failed' -or $result -notmatch 'CONCEPT COMPLETE') { throw "Preview failed: $($p.ExitCode)" }
