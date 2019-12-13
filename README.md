# NameMarketplace

Elixir SDK team decided to build name marketplace showcase application. Name marketplace allows everyone who owns some name - list it for his own price. We decided to build backend part only by using our SDK and Elixir language. The app in future would act as a middleman between sellers and buyers,(but currently only selling functionality is supported).
In order to sell a name - a potential **seller** would have to:
1. Make a **Spend** transaction, which includes a price and a name, that he wants to sell and he must put 10% of the payload's given price(could be adjusted by the owner of marketplace) in the amount of the transaction, this is a request service fee. This information should be included in a payload of a SpendTx,  in a following format: `price-name`.  
2. Make a transfer transaction after the spend transaction is verified and confirmed. User has 2 minutes(by default, could be set in a `config.exs` file, under `:gc_time` option in seconds) in order to transfer a name to us, otherwise he will lose his transferred amount.


### Under-development section 
This app will also provide functionality for everyone who is looking for some name to buy - name listing and buying in future.

A potential **buyer** would have to:
1. List all available names
2. Pick a desired name
3. Make a spend transaction, with a payload in following format: `name-price` , and amount of that transaction should be also equal to the price of the listed name + 5% service fee.
4. If the transaction is valid and our middleman still owns a given name - we will transfer it to the buyer.

### Usage
1. Clone the project:
```
git clone https://github.com/DanielaIvanova/name_marketplace
cd name_marketplace
```

2. You have to set your own app configuration, like keys, network id , etc.
An example config can be found in `config\config.exs` file.

3. After all things set up, we have to get dependencies, compile everything and run our project:
```
mix deps.get
iex -S mix
```
4. In the `IEX` shell, you will have to start  the `Websocket` process:
```
NameMarketplace.start_link()
```
4. As the service is running, you can `subscribe()` for a defined middleman account, or you can `subscribe("ak_someaccount")`.Subscribing will try to start **listening** for the incomming/outcomming transactions of the given account public key, by making use of Websocket protocol:
```
NameMarketplace.subscribe()
``` 

