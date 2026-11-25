# Best Food & Drink

Never dig through your bags for food and water again. Best Food & Drink scans your bags and shows the best food and the best drink you can use as two one-click buttons on your screen.

## Features

- **Two buttons:** one for food (health) and one for drink (mana).
- **Automatic choice:** picks the item with the highest restore value that your character can already use (level requirement is respected).
- **Mage-conjured items first:** conjured food and water are always preferred over regular items. Among the same kind, the highest value wins.
- **Manual override:** don't like the automatic pick? Choose any food or drink from your bags yourself.
- **Always up to date:** updates when your bags change, when you level up, and after combat.
- **Info at a glance:** item icon, stack count and cooldown are shown on each button.
- **Localized:** English, German, French and Spanish, following your client language.

## How to use

1. Install the addon and start the game (or type `/reload`).
2. Two buttons appear on your screen: Food and Drink.
3. **Left-click** a button to use the item.
4. **Alt + Left-click** a button to open a dropdown menu with all usable food or drink items in your bags.
5. Click an item to select it. The button gets a green border.
6. Choose **Automatic (best item)** to go back to the automatic selection.
7. If your chosen item is no longer in your bags, the best available item is used instead.
8. **Shift + Drag** a button to move both buttons.

## Slash commands

| Command | Description |
| --- | --- |
| `/bfd lock` | Lock the buttons in place |
| `/bfd unlock` | Unlock the buttons (Shift + Drag) |
| `/bfd scale <0.5-3>` | Change the scale |
| `/bfd size <20-100>` | Change the button size |
| `/bfd auto` | Reset both buttons to automatic selection |
| `/bfd reset` | Reset position, size and selection |
| `/bfd refresh` | Rescan your bags |
| `/bfd debug` | Print parsed values of all food and drink items in your bags |

## Notes

- Buttons use secure actions, so they can only be changed outside of combat. Changes are applied as soon as combat ends.
- Only items from the "Food & Drink" category are considered. The restore value is read from the item tooltip.

## Feedback

Found a bug or have an idea? Please leave a comment or open an issue. If you report an error, include the Lua error text (for example from BugSack).
