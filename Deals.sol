pragma solidity ^0.4.18;

contract Deal {

  /// The seller's address
  address public owner;

  /// The buyer's address part on this contract
  address public buyerAddr;

  /// The Buyer struct  
  struct Buyer {
    address addr;
    string name;

    bool init;
  }

  /// The Shipment struct
  struct Shipment {
    address courier;
    uint price;
    uint safepay;
    address payer;
    uint date;
    uint real_date;

    bool init;
  }

  /// The Order struct
  struct Order {
    string goods;
    uint quantity;
    uint number;
    uint price;
    uint safepay;
    Shipment shipment;

    bool init;
  }

  /// The Invoice struct
  struct Invoice {
    uint orderno;
    uint number;

    bool init;
  }

  /// The mapping to store orders
  mapping (uint => Order) orders;

  /// The mapping to store invoices
  mapping (uint => Invoice) invoices;

  /// The sequence number of orders
  uint orderseq;

  /// The sequence number of invoices
  uint invoiceseq;

  /// Event triggered for killing contract
  event KillContract(address buyer,string message);

  /// Event triggered for every registered buyer
  event BuyerRegistered(address buyer,string message);

  /// Event triggered for every new order
  event OrderPlaced(address buyer, string goods, uint quantity, uint orderno);

  /// Event triggerd when the order gets valued and wants to know the value of the payment
  event PriceShare(address buyer, uint orderno, uint price, int8 ttype);

  /// Event trigger when the buyer performs the safepay
  event SafepaySent(address buyer, uint orderno, uint value, uint now);

  /// Event triggered when the seller sends the invoice
  event InvoiceSent(address buyer, uint invoiceno, uint orderno, uint delivery_date, address courier);

  /// Event triggered when the courie delives the order
  event OrderDelivered(address buyer, uint invoiceno, uint orderno, uint real_delivey_date, address courier);

  /// The smart contract's constructor
  function Deal(address _buyerAddr) public payable {
    
    /// The seller is the contract's owner
    owner = msg.sender;

    buyerAddr = _buyerAddr;
	
	emit BuyerRegistered(buyerAddr,"Registered Buyer");
  }

  /// The function to send purchase orders
  ///   requires fee
  ///   Payable functions returns just the transaction object, with no custom field.
  ///   To get field values listen to OrderSent event.
  function placeOrder(string goods, uint quantity) payable public {
    
    /// Accept orders just from buyer
    require(msg.sender == buyerAddr,"Accept orders just from buyer");

    /// Increment the order sequence
    orderseq++;

    /// Create the order register
    orders[orderseq] = Order(goods, quantity, orderseq, 0, 0, Shipment(0, 0, 0, 0, 0, 0, false), true);

    /// Trigger the event
    emit OrderPlaced(msg.sender, goods, quantity, orderseq);

  }

  /// The function to query orders by number
  ///   Constant functions returns custom fields
  function queryOrder(uint number) constant public returns (address buyer, uint price, uint safepay, uint delivery_price, uint delivey_safepay, uint total_price) {
    
    /// Validate the order number
    require(orders[number].init,"Invalid order number");

    /// Return the order data
    return(buyerAddr, orders[number].price, orders[number].safepay, orders[number].shipment.price, orders[number].shipment.safepay, orders[number].price + orders[number].shipment.price);
  }

  /// The function to send the price to pay for order
  ///  Just the owner can call this function
  ///  requires free
  function sharePrice(uint orderno, uint price, int8 ttype) payable public {
  
    /// Only the owner can use this function
    require(msg.sender == owner,"Only the owner can use this function");

    /// Validate the order number
    require(orders[orderno].init,"Invalid order number");

    /// Validate the type
    ///  1=order
    ///  2=shipment
    require(ttype == 1 || ttype == 2,"Invalid Type 1=order, 2=shipment");

    if(ttype == 1){/// Price for Order

      /// Update the order price
      orders[orderno].price = price;

    } else {/// Price for Shipment

      /// Update the shipment price
      orders[orderno].shipment.price = price;
      orders[orderno].shipment.init  = true;
    }

    /// Trigger the event
    emit PriceShare(buyerAddr, orderno, price, ttype);

  }

  /// The function to send the value of order's price
  ///  This value will be blocked until the delivery of order
  ///  requires fee
  function sendSafepay(uint orderno) payable public {

    /// Validate the order number
    require(orders[orderno].init,"Invalid order number");

    /// Just the buyer can make safepay
    require(buyerAddr == msg.sender,"Only the buyer can make safepay");

    /// The order's value plus the shipment value must equal to msg.value
    require((orders[orderno].price + orders[orderno].shipment.price) == msg.value/1000000000000000000,"The order's value plus the shipment value must equal to msg.value");

    orders[orderno].safepay = orders[orderno].price * 1000000000000000000;
	orders[orderno].shipment.safepay = orders[orderno].shipment.price * 1000000000000000000;

    emit SafepaySent(msg.sender, orderno, msg.value, now);
  }

  /// The function to send the invoice data
  ///  requires fee
  function sendInvoice(uint orderno, uint delivery_date, address courier) payable public {

    /// Validate the order number
    require(orders[orderno].init,"Invalid order number");

    /// Just the seller can send the invoice
    require(owner == msg.sender,"Only the seller can send the invoice");

    invoiceseq++;

    /// Create then Invoice instance and store it
    invoices[invoiceseq] = Invoice(orderno, invoiceseq, true);

    /// Update the shipment data
    orders[orderno].shipment.date    = delivery_date;
    orders[orderno].shipment.courier = courier;

    /// Trigger the event
    emit InvoiceSent(buyerAddr, invoiceseq, orderno, delivery_date, courier);
  }

  /// The function to get the sent invoice
  ///  requires no fee
  function getInvoice(uint invoiceno) constant public returns (address buyer, uint orderno, uint delivery_date, address courier){
  
    /// Validate the invoice number
    require(invoices[invoiceno].init,"Invalid invoice number");

    Invoice storage _invoice = invoices[invoiceno];
    Order storage _order     = orders[_invoice.orderno];

    return (buyerAddr, _order.number, _order.shipment.date, _order.shipment.courier);
  }

  /// The function to mark an order as delivered
  function delivery(uint invoiceno, uint timestamp) payable public {

    /// Validate the invoice number
    require(invoices[invoiceno].init,,"Invalid invoice number");

    Invoice storage _invoice = invoices[invoiceno];
    Order storage _order     = orders[_invoice.orderno];

    /// Just the courier can call this function
    require(_order.shipment.courier == msg.sender,"Only the courier can call this function");

    emit OrderDelivered(buyerAddr, invoiceno, _order.number, timestamp, _order.shipment.courier);

    /// Payout the Order to the seller
    owner.transfer(_order.safepay);

    /// Payout the Shipment to the courier
    _order.shipment.courier.transfer(_order.shipment.safepay);

  }

  function health() pure public returns (string) {
    return "running";
  }
  
  function closeContract() public { //self-destruct function, 
   if(msg.sender == owner) {
    emit KillContract(buyerAddr,"Killing Contract");
	selfdestruct(owner); 	
	}	
  }
}