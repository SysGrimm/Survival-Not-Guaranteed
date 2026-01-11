// Hide items from EMI (client-side)
// This removes items from EMI's item list and search
// Must restart game for this to take effect (F3+T reload won't work)

// Correct KubeJS API for EMI - uses RecipeViewerEvents
RecipeViewerEvents.removeEntries('item', event => {
    // Add items to hide here
    // Example: event.remove('modid:item_name')
})
