pragma solidity ^0.4.15;

import "./Owned.sol";
import "./SafeMath.sol";
import "./Tokenza.sol";

/**
    @notice This contract implements a hyperlocal store that can interact with
    registered customers, riders. Every customer has its own shopping cart.
    @title Retail Store Contract
    @author Gathuto G
*/
contract Store is Owned, SafeMath {

    /* Store internals */
    
    string public store_name; // store name
    uint256 private store_balance;  // store balance
    
    string public location;
    
    uint public lat;
    uint public long;
    
    
    
    uint public registeredCustomers;
    uint public registeredProducts;
    uint public registeredRiders;

    /* Store Events */
    event CustomerRegistered(address customer);
    event CustomerRegistrationFailed(address customer);
    event CustomerDeregistered(address customer);
    event CustomerDeregistrationFailed(address customer);

    event ProductRegistered(uint256 productId);
    event ProductDeregistered(uint256 productId);
    event ProductRegistrationFailed(uint256 productId);
    event ProductDeregistrationFaled(uint256 productId);

    event CartProductInserted(address customer, uint256 prodId, uint256 prodPrice, uint256 completeSum);
    event CartProductInsertionFailed(address customer, uint256 prodId);
    event CartProductRemoved(address customer, uint256 prodId);
    event CartCheckoutCompleted(address customer, uint256 paymentSum);
    event CartCheckoutFailed(address customer, uint256 customerBalance, uint256 paymentSum);
    event CartEmptied(address customer);

    /**
        @notice every customer has an address, name,
        balance and a shopping cart
    */
    struct Customer {
        address adr;
        bytes32 name;
        uint256 balance;
       
       mapping(uint => Receipt) myReceipts;
       uint loyaltyPoints;
       
        Cart cart;
    }

    /**
        @notice A shopping cart contains an array of product ids: @products
        and a sum of product prices: @completeSum
        The @completeSum gets automatically updated when customer
        adds or removes products.
    */
    struct Cart {
      uint256[] products;
      uint256 completeSum;
      
      bool auctionDelivery;
 //      Delivery xx;
    }

    /**
        @notice Represents a product:
        Product id: @id
        Product name: @name
        Decription: @description
        Amount of items in a single product: @default_amount
    */
    struct Product {
        uint256 type_id;
        string name;
        bytes32 description;
        // uint expiryDate;
        // string manufacturer;
        bytes32 image;
        uint256 price;
        uint256 default_amount;
        uint256 totalItems;
        
        mapping(uint => Item) Items;
    }
    
    struct Item {
        bool inStore;
        uint item_id;
        uint storeTime;
        
    }
    
    /**
        @notice Represents a receipt [NOT IN USE]
    */
    struct Receipt {
        InvoiceLine[] lines;
        address customer_address;
        
    }

    /**
        @notice Represents a single entry describing a single product [NOT IN USE]
    */
    struct InvoiceLine {
        bytes product_id;
        uint256 amount;
        uint256 product_price;
        uint256 total_price;
    }
    
    struct Delivery {
        address custodian;
        bool inTransit;
        bool delivery;
        string review;
        
        Receipt x;
    }
    
    mapping(uint => mapping(bool => Delivery)) awaitingDelivery;
    
     struct Bool {
        bool trackMode;
        uint _timed;
        
    } 
    
     struct Rider {
        bool isRider;
        address adr;
        bytes32 name;
        
        uint charges_per_mile;
        bool isReady;
        uint stake;
        mapping(address => Bool) allowTracking; 
        mapping(uint => Delivery) myDeliveries;
        
    }
    
    mapping(uint => string) public reviews;
    
    YGlobalToken public xxx;
    
    uint public delegatedStake;
    mapping (address => Customer) customers;
    mapping (uint256 => Product) products;
    mapping(address => Rider) riders; 
    
    /**
        @notice Default constructor
    */
    function Store(address _tokenize, address _admin, string _sname, string _location, uint _lat, uint _long) {
        owner = _admin;
        store_name = _sname;
        location = _location;
        lat = _lat;
        long = _long;
        
        store_balance = 0;
        
        xxx = YGlobalToken(_tokenize);
        
       // if (this.balance > 0) revert();
    }

    /**
          @notice Payable fallback
    */
    function() payable {

    }

    /**
          @notice Register a single product
          @param id Product ID
          @param name Product Name
          @param description Product Description
          @param price Product Price
          @param default_amount Default amount of items in a single product
          @return success
    */
    function registerProduct(uint256 id, string name, bytes32 description, bytes32 _image,
                             uint256 price, uint256 default_amount, uint256 totalItems)
                                         onlyOwner returns (bool success) {
        var product = Product(id, name, description, _image, price, default_amount, totalItems);
        if (checkProductValidity(product)) {
            products[id] = product;
            registeredProducts++;
            ProductRegistered(id);
            return true;
        }
        ProductRegistrationFailed(id);
        return false;
        }
        
    function addItem(uint product_id, uint amount) public onlyOwner 
    {
        
    }

    /* *
          @notice Removes a product from the list
          @param id Product ID
          @return success
    */
    function deregisterProduct(uint256 id) onlyOwner returns (bool success) {
      Product storage product = products[id];
      if (product.type_id == id) {
        delete products[id];
        registeredProducts--;
        ProductDeregistered(id);
        return true;
      }
      ProductDeregistrationFaled(id);
      return false;
    }

    /**
          @notice Registers a new customer (only store owners)
          @param _address Customer's address
          @param _name Customer's name
          @param _balance Customer's balance
          @return success
    */
    function registerCustomer(address _address, bytes32 _name, uint _balance)
                                        onlyOwner returns (bool success) {
      if (_address != address(0)) {
        Customer memory customer = Customer({ adr: _address, name: _name, balance: _balance,
                                              loyaltyPoints: 0,
                                              cart: Cart(new uint256[](0), 0, true)
                                            });
        customers[_address] = customer;
        registeredCustomers++;
        CustomerRegistered(_address);
        return true;
      }
      CustomerRegistrationFailed(_address);
      return false;
    }

    /**
        @notice Removes a customer (only store owners)
        @param _address Customer's address
        @return success
    */
    function deregisterCustomer(address _address) onlyOwner public  returns (bool success) {
      Customer storage customer = customers[_address];
      if (customer.adr != address(0)) {
        delete customers[_address];
        registeredCustomers--;
        
        CustomerDeregistered(_address);
        return true;
      }
      CustomerDeregistrationFailed(_address);
      return false;
    }
    
    function registerRider(address newRider) public onlyOwner
    {
        riders[newRider].isRider = true;
        registeredRiders++;
    }
    
    function deregisterRider(address abortRider) public onlyOwner
    {
        riders[abortRider].isRider = false;
        registeredRiders--;
    }
    
    
    /**
        @notice Inserts a product into the shopping cart.
        This function returns a boolean and the position of the
        inserted product.
        The positional information can later be used to directly reference
        the product within the mapping. Solidity mappings aren't interable.
        @param id Product ID
        @return (success, pos_in_prod_mapping)
    */
    
    function insertProductIntoCart(uint256 id) returns (bool success,
                                                  uint256 pos_in_prod_mapping) {
        Customer storage cust = customers[msg.sender];
        Product storage prod = products[id];
        uint256 prods_prev_len = cust.cart.products.length;
        cust.cart.products.push(prod.type_id);
        uint256 current_sum = cust.cart.completeSum;
        cust.cart.completeSum = safeAdd(current_sum, prod.price);
        if (cust.cart.products.length > prods_prev_len) {
          CartProductInserted(msg.sender, id, prod.price, cust.cart.completeSum);
          return (true, cust.cart.products.length - 1);
          
         //  xxx.approve(this, prod.price);
        }
        CartProductInsertionFailed(msg.sender, id);
        return (false, 0);
    }

    /**
        @notice Removes a product entry from the shopping cart
        @param prod_pos_in_mapping Product's position in the internal mapping
    */
    function removeProductFromCart(uint256 prod_pos_in_mapping) {
      /*if (msg.sender != owner) {*/
        uint256[] memory new_product_list = new uint256[](customers[msg.sender]
                                                    .cart.products.length - 1);
        var customerProds = customers[msg.sender].cart.products;
        for (uint256 i = 0; i < customerProds.length; i++) {
          if (i != prod_pos_in_mapping) {
            new_product_list[i] = customerProds[i];
          } else {
            customers[msg.sender].cart.completeSum -=
                                               products[customerProds[i]].price;
            CartProductRemoved(msg.sender, customerProds[i]);
          }
        }
        customers[msg.sender].cart.products = new_product_list;
      /*}*/
    }

    /**
        @notice Invokes a checkout process that'll use the current shopping cart to
        transfer balances between the current customer and the store
        @return success
    */
    function checkoutCart() returns (bool success) {
        Customer storage customer = customers[msg.sender];
        uint256 paymentSum = customer.cart.completeSum;
        if ((customer.balance >= paymentSum) &&
            customer.cart.products.length > 0) {
            customer.balance -= paymentSum;
            customer.cart = Cart(new uint256[](0), 0, true);
            xxx.transferFrom(customer.adr, this, paymentSum);
            
            store_balance += paymentSum;
            CartCheckoutCompleted(msg.sender, paymentSum);
            return true;
        }
        CartCheckoutFailed(msg.sender, customer.balance, paymentSum);
        return false;
    }

    /**
          @notice Empties the shopping cart
          @return success
    */
    function emptyCart() returns (bool success) {
      /*if (msg.sender != owner) {*/
        Customer storage customer = customers[msg.sender];
        customer.cart = Cart(new uint256[](0), 0, true);
        CartEmptied(customer.adr);
        return true;
      /*}*/
      /*return false;*/
    }

    function commitRider() public
    {
        if(riders[msg.sender].isRider != true) revert();
    }
    
    function approveDelivery() public
    {
        
    }
    
    function rejectDelivery() public
    {
        
    }
    
    function disputeResolve() internal
    {
        
    }
    
     function renameStore(string _store) onlyOwner public {
       
            store_name = _store;
           // return true;
       
    }
    
    function cashOUt(address _to, uint amount) onlyOwner public
    {
        xxx.transfer(_to, amount);
    }
    
   

    /**
          @notice Returns a elements describing a product
          @param id Product ID
          @return (name, description, price, default_amount)
    */
    function getProduct(uint256 id) constant returns (string name,
                                                      bytes32 description,
                                                      uint256 price,
                                                      uint256 default_amount) {
       return (products[id].name,
               products[id].description,
               products[id].price,
               products[id].default_amount);
    }

    /**
        @notice Returns a list of product ids and a complete sum.
        The caller address must be a registered customer.
        @return (product_ids, complete_sum)
    */
    function getCart() constant returns (uint256[] memory product_ids,
                                                          uint256 complete_sum) {
      Customer storage customer = customers[msg.sender];
      uint256 len = customer.cart.products.length;
      uint256[] memory ids = new uint256[](len);
      for (uint256 i = 0; i < len; i++) {
        ids[i] = products[i].type_id;
      }
      return (ids, customer.cart.completeSum);
    }

    /**
          @notice Returns customer's balance
          @return _balance Customer's balance
    */
    function getBalance() constant returns (uint256 _balance) {
      return customers[msg.sender].balance;
    }

    /**
          @notice Returns stores's own balance
          @return store_balance Store's current balance
    */
    function getStoreBalance() onlyOwner constant returns (uint256) {
      return store_balance;
    }

    /**
          @notice Checks product validity
          @param product Product struct
          @return valid
    */
    function checkProductValidity(Product product) private returns (bool valid) {
       return (product.price > 0);
    }
}


contract storeFactory {
    
    YGlobalToken public xx;
    
    string public dapp_name;
    address public dev;
    
    mapping(uint => address) public stores;
    uint public registeredStores;
    
    mapping(address => mapping(address => uint)) public delegateRegistry;
    
    function storeFactory(address _tokenza, string _name) public
    {
       dapp_name = _name;
       dev = msg.sender;
       
       xx = YGlobalToken(_tokenza);
    }
    
    function registerStorey(string store_name, string _location, uint _lat, uint _long) public
    {
        address storex = new Store(xx, msg.sender, store_name, _location, _lat, _long);
        if(storex != address(0x0))
        {
            stores[registeredStores] = storex;
            registeredStores++;
        }
    }
    
    function delegateStore(address store, uint amount) public
    {
        
    }
    function undelegateStore(address store, uint amount) public
    {
        
    }
    
}
