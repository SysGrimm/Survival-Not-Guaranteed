// Hide items from EMI (client-side)
// This removes items from EMI's item list and search
// Must restart game for this to take effect (F3+T reload won't work)

// Correct KubeJS API for EMI - uses RecipeViewerEvents
RecipeViewerEvents.removeEntries('item', event => {
    // Mekanism MekaSuit - Armor Pieces
    event.remove('mekanism:mekasuit_helmet')
    event.remove('mekanism:mekasuit_bodyarmor')
    event.remove('mekanism:mekasuit_pants')
    event.remove('mekanism:mekasuit_boots')
    
    // Mekanism MekaSuit - Modules & Upgrades
    event.remove('mekanism:module_base')
    event.remove('mekanism:module_energy_unit')
    event.remove('mekanism:module_color_modulation_unit')
    event.remove('mekanism:module_laser_dissipation_unit')
    event.remove('mekanism:module_radiation_shielding_unit')
    event.remove('mekanism:module_electrolytic_breathing_unit')
    event.remove('mekanism:module_inhalation_purification_unit')
    event.remove('mekanism:module_vision_enhancement_unit')
    event.remove('mekanism:module_nutritional_injection_unit')
    event.remove('mekanism:module_jetpack_unit')
    event.remove('mekanism:module_gravitational_modulating_unit')
    event.remove('mekanism:module_charge_distribution_unit')
    event.remove('mekanism:module_dosimeter_unit')
    event.remove('mekanism:module_geiger_unit')
    event.remove('mekanism:module_elytra_unit')
    event.remove('mekanism:module_locomotive_boosting_unit')
    event.remove('mekanism:module_gyroscopic_stabilization_unit')
    event.remove('mekanism:module_hydrostatic_repulsor_unit')
    event.remove('mekanism:module_motorized_servo_unit')
    event.remove('mekanism:module_hydraulic_propulsion_unit')
    event.remove('mekanism:module_magnetic_attraction_unit')
    event.remove('mekanism:module_frost_walker_unit')
    event.remove('mekanism:module_soul_surfer_unit')
    
    // MekanismGenerators modules
    event.remove('mekanismgenerators:module_solar_recharging_unit')
    event.remove('mekanismgenerators:module_geothermal_generator_unit')
})
