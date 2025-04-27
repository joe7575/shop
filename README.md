# Shop [shop]

Sales stand (shop) and banknotes for players to sell and exchange goods.

Copyright 2017 James Stevenson, 2019-2025 Joachim Stolberg  

## Description

This mod adds a sales stand (shop) and banknotes for players to sell and exchange goods.
In addition to the banknotes, the mod also adds a debit card, which can be used to pay
for goods in the shop.

To use the debit card, the player simply has to have it in their inventory. The shop
will automatically detect the card and use it to pay for the goods.
However, if the player has cash in hand (wielded item), the shop will use the cash
instead of the debit card.

If the debit card is deposited in the register of the shop, a transfer instead of
cash payment is made.

### Offer Overview Board

The Offer Overview board gives an overview of the current offers in all shops.
The board is updated every hour and shows the current offers from all shops.
To update the board manually, use the command `/offer_update` (requires "server" privs).

### Chat Commands

- Check the balance of the debit card with `/balance`
- Set the account balance with: `/set_balance <player> <value>` (requires "server" privs)
- Update the offer overview with: `/offer_update` (requires "server" privs)

### Central Bank

The role of the Central Bank is to issue banknotes and debit cards.
This can be done by using the shop. The shop can be used to spend money for ores
or other items and to issue debit cards against banknotes.
As a bank the shop can also be used to top up credit cards.
For this the Gold Card has to be placed in the shop's stock.
The owner of the Gold Card has unlimited credit, the card should be used with care or only
used for the Central bank to issue debit cards.

## License of source code

This mod is free software; you can redistribute and/or
modify it under the terms of the GNU General Public License version 3 or later
published by the Free Software Foundation.

This mod is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public
License along with this mod; if not, write to the
Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
Boston, MA  02110-1301, USA.

## License of media (textures, sounds and documentation)

All textures, sounds and documentation files are licensed under the
Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)
http://creativecommons.org/licenses/by-sa/3.0/
