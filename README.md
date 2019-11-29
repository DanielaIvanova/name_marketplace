# NameMarketplace

Elixir SDK team decided to build name marketplace showcase application. Name marketplace allows everyone who owns some name - list it for his own price and for everyone who is looking for some name to buy - name listing and buying functionality. We decided to build backend part only by using our SDK and Elixir language. The app acts as a middleman between sellers and buyers. In order to sell a name - a potential **buyer** would have to:
1. Make a **Spend** transaction, which includes a price and a name, that he wants to sell and he must put 10% of the payload's given price(could be adjusted by the owner of marketplace) in the amount of the transaction, this is a request service fee. This information should be included in a payload of a SpendTx,  in a following format: `price-name`.  
2. Make a transfer transaction after the spend transaction is verified and confirmed. User has ~3 minutes(1 keyblock) in order to transfer a name to us, otherwise he will lose his 10% amount.

A potential **buyer** would have to:
1. List all available names
2. Pick a desired name
3. Make a spend transaction, with a payload in following format: `name-price` , and amount of that transaction should be also equal to the price of the listed name + 5% service fee.
4. If the transaction is valid and our middleman still owns a given name - we will transfer it to the buyer.

### Usage

1. First of all you have to set your own app configuration, like keys, network id , etc.
An example config can be found in `config\config.exs` file.
2. After all things set up, we have to get dependencies, compile everything and run our project:
```
mix deps.get
iex -S mix
```
3. In the `IEX` shell, you will have to start  the `name marketplace` process:
```
NameMarketplace.start_link
```
4. As the process is running, you can check the current state of all names in the marketplace:
```
NameMarketplace.state
``` 

