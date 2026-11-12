param([ValidateSet('play','rules','ui')][string]$Mode='play')
& (Join-Path $PSScriptRoot 'run_combat_trial.ps1') -Scenario wreckage -Mode $Mode
