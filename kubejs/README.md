# KubeJS Scripts

KubeJS allows you to modify recipes, add custom items, change loot tables, and more using JavaScript.

## Folder Structure

```
kubejs/
├── server_scripts/     # Server-side scripts (recipes, loot, tags, etc.)
├── client_scripts/     # Client-side scripts (tooltips, UI, etc.)
├── startup_scripts/    # Runs before world loads (item/block registration)
└── data/              # Custom data (recipes, tags, etc.)
```

## Current Scripts

### server_scripts/disable_ars_weapons.js
Removes crafting recipes for all Ars Nouveau weapons:
- Enchanters Sword, Shield, Bow
- Sorcerer Sword, Shield, Bow
- Battlemage Sword, Shield, Bow
- Archmage Sword, Shield, Bow
- Spellbow

**To modify:** Edit the `arsWeapons` array to add/remove items

## How to Use

1. **Edit scripts** - Files reload on `/kubejs reload` command or game restart
2. **Check logs** - Look in `logs/latest.log` for KubeJS output
3. **Add more items** - Just add IDs to the array, like: `'modid:item_name'`

## Common Tasks

### Remove more recipes:
```javascript
event.remove({ output: 'mod:item_id' })  // By output
event.remove({ input: 'mod:item_id' })   // By input
event.remove({ mod: 'modname' })         // All recipes from mod
```

### Hide from JEI:
Create `client_scripts/hide_items.js`:
```javascript
JEIEvents.hideItems(event => {
    event.hide('ars_nouveau:enchanters_sword')
})
```

### Add custom recipes:
```javascript
event.shaped('minecraft:diamond', [
    'SSS',
    'SSS',
    'SSS'
], {
    S: 'minecraft:stick'
})
```

## Documentation
- Full docs: https://kubejs.com/
- Discord: https://discord.gg/lat
