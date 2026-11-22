# Changelog

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
