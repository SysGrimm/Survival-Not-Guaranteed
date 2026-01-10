// Disable specific item recipes
// Add any mod:item_id to remove its crafting recipe
ServerEvents.recipes(event => {
    const itemsToDisable = [
        // Mekanism MekaSuit - Armor Pieces
        'mekanism:mekasuit_helmet',
        'mekanism:mekasuit_bodyarmor',
        'mekanism:mekasuit_pants',
        'mekanism:mekasuit_boots',
        
        // Mekanism MekaSuit - Modules & Upgrades
        'mekanism:module_base',
        'mekanism:module_energy_unit',
        'mekanism:module_color_modulation_unit',
        'mekanism:module_laser_dissipation_unit',
        'mekanism:module_radiation_shielding_unit',
        'mekanism:module_electrolytic_breathing_unit',
        'mekanism:module_inhalation_purification_unit',
        'mekanism:module_vision_enhancement_unit',
        'mekanism:module_nutritional_injection_unit',
        'mekanism:module_jetpack_unit',
        'mekanism:module_gravitational_modulating_unit',
        'mekanism:module_charge_distribution_unit',
        'mekanism:module_dosimeter_unit',
        'mekanism:module_geiger_unit',
        'mekanism:module_elytra_unit',
        'mekanism:module_locomotive_boosting_unit',
        'mekanism:module_gyroscopic_stabilization_unit',
        'mekanism:module_hydrostatic_repulsor_unit',
        'mekanism:module_motorized_servo_unit',
        'mekanism:module_hydraulic_propulsion_unit',
        'mekanism:module_magnetic_attraction_unit',
        'mekanism:module_frost_walker_unit',
        'mekanism:module_soul_surfer_unit',
        // MekanismGenerators modules:
        'mekanismgenerators:module_solar_recharging_unit',
        'mekanismgenerators:module_geothermal_generator_unit',
    ]
    
    itemsToDisable.forEach(item => {
        event.remove({ output: item })
        console.info(`Disabled crafting for: ${item}`)
    })
})
