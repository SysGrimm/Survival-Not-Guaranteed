// Disable specific item recipes
// Add any mod:item_id to remove its crafting recipe
ServerEvents.recipes(event => {
    const itemsToDisable = [
        // Add items to disable here
        // Example: 'modid:item_name',
    ]
    
    itemsToDisable.forEach(item => {
        event.remove({ output: item })
        console.info(`Disabled crafting for: ${item}`)
    })
})
