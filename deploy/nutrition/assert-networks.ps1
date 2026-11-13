function Assert-NutritionNetworks($Config) {
    if ($Config.networks.'nutrition-data'.internal -ne $true) { throw 'Nutrition data network must be internal.' }
    $networks = @($Config.services.nutrition.networks.PSObject.Properties.Name)
    if ($networks -contains 'edge' -or $networks -contains 'data') { throw 'Nutrition must not join edge/data.' }
    foreach ($flag in @('HealthParser__Enabled', 'MealRanking__Enabled')) {
        if ($Config.services.nutrition.environment.$flag -eq 'true' -and
            ($networks -notcontains 'nutrition-egress' -or
             -not $Config.networks.'nutrition-egress' -or
             $Config.networks.'nutrition-egress'.internal -eq $true)) {
            throw 'Enabled Nutrition AI requires a non-internal nutrition-egress network.'
        }
    }
    foreach ($service in $Config.services.PSObject.Properties) {
        $attached = @($service.Value.networks.PSObject.Properties.Name)
        if ($service.Name -ne 'nutrition' -and $attached -contains 'nutrition-egress') {
            throw 'Only Nutrition may join nutrition-egress.'
        }
        if ($service.Name -in @('nutrition-db', 'nutrition-migrate', 'nutrition-backup', 'nutrition-restore-check', 'nutrition-demo-catalog') -and
            ($attached.Count -ne 1 -or $attached[0] -ne 'nutrition-data')) {
            throw 'Nutrition database and jobs must stay only on nutrition-data.'
        }
    }
}
