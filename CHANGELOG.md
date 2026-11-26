# Changelog

## 1.0.2
**Servers**
- The Connector tool now checks whose part it is. Before, anyone could link your cells into their network and drain them, or remove all your links. Admins can still link anything.
- Parts placed with the Parts tool belong to whoever placed them, so their cables follow "Others see my cables".

**Fixed**
- The Parts tool shows a ghost of the part again, and a display's ghost hangs on the wall where it'll go.
- Machine sounds stop when the machine is switched off or far away, and "Machine sounds" off works right away.
- The Connector tool's right click doesn't link parts to a crate anymore.
- A Gravity Regulator works after loading a saved game.
- Cells, nodes and the other screens show energy first again. A floating screen isn't covered by things behind it.
- Cables don't hang into the floor, and having lots of devices in view costs less (113 to 188 fps in one test).
- The suit display and the Environment Probe name a life support area in your own language, and the suit countdown doesn't freeze in noclip.
- On servers that limit noclip in space, a seat in space now works the same for players and admins (the suit ran for some and not for others).

**Changed**
- In space, sitting in a seat no longer gives you air by itself. You need the ship's life support or your suit, like on foot. Admins can turn this off with "Seats in space" in the Grid Power settings.

## 1.0.1
**New**
- Heavy Water Extractor (Generators): 200 water + 600 000 energy make 1 heavy water a second, the Fusion Reactor's fuel. Own model with a glowing window and a spinning centrifuge.
- Fuel Cell (Life support): 2 hydrogen + 1 oxygen make 2 water and a little energy - a ship in space makes its own water from the Ram Scoop's hydrogen.
- The Life Support Core breathes out carbon dioxide (Wire output "Carbon Dioxide") for the Hydroponics, so the air cycle on a ship closes.
- The Air Compressor can collect nitrogen instead of oxygen (E or Wire "Nitrogen").
- The Terraformer is in the spawn menu.

**Changed**
- On a planet the Air Compressor takes its oxygen (or nitrogen) out of the planet's air, never more than the air has.
- A pasted copy starts empty (a loaded save keeps everything).
- Shorter, clearer English texts; every language has all texts.
- The spawn menu shows Ascension Gates, SpaceGrid and PowerGrid side by side.

**Fixed**
- Steam Turbine window and Hydroponics glass and leaves were drawn solid.
- Parts no longer change their look from far away; the Wind Turbine icon shows its rotor.
- Copied parts work on their own: a copied Life Support Core, power node, Gravity Regulator, tank or valve no longer acts on the original.
- The Fusion Reactor no longer burns a whole heavy water when only a little energy fits.
- A closed valve separates welded networks in Automatic / Mix mode; switching to "Off (free energy)" no longer cuts every network.
- The Terraformer finishes on planets with too much oxygen; it and the Gravity Regulator use no energy while Spacebuild runs the air; a planet added without a position no longer breaks life support.

## 1.0.0
First release.

- Energy network: solar, wind, fusion, hydro, steam; cells XS-XL, nodes, displays, valve, tanks
- Life support: core, space suits with HUD, dispenser, heaters and coolers, compressor, pumps, hydroponics, terraformer, gravity regulator
- Parts tool with a ghost preview, Connector tool, link modes manual / automatic / mix
- Uses Spacebuild's Resource Distribution when Spacebuild is installed
- All texts in 12 languages
