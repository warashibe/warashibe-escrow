pragma experimental ABIEncoderV2;
pragma solidity ^0.5.8;
import "../openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract Escrow  {
  address public owner;
  struct EscrowStruct
  {    
    address buyer;
    address seller;
                                       
    uint escrow_fee;
    uint amount;

    bool escrow_intervention;
    bool release_approval;
    bool refund_approval; 

    bytes32 notes;

    address[] tokens;
    uint[] amounts;
    uint[] fees;
    uint token_length;
  }
  
  struct TransactionStruct
  {                        
    address buyer; 
    uint buyer_nounce;
  }
  
  mapping(address => EscrowStruct[]) public buyerDatabase;

  mapping(address => TransactionStruct[]) public sellerDatabase;        
  TransactionStruct[] public escrowDatabase;
               
  uint public escrowFee;

  constructor(uint fee) public {
    owner = msg.sender;
    escrowFee = fee;
  }

  function setEscrowFee(uint fee) public {
    require (fee >= 0 && fee <= 1000 && msg.sender == owner);
    escrowFee = fee;
  }

  function newEscrow(address sellerAddress, bytes32 notes, address[] memory tokens, uint[] memory amounts) public payable returns (bool success) {

    require(msg.value > 0 && msg.sender != owner);
        
    EscrowStruct memory currentEscrow;
    TransactionStruct memory currentTransaction;
            
    currentEscrow.buyer = msg.sender;
    currentEscrow.seller = sellerAddress;

    currentEscrow.escrow_fee = escrowFee*msg.value/1000;
    currentEscrow.amount = msg.value - currentEscrow.escrow_fee;
    currentEscrow.token_length = tokens.length;
    currentEscrow.fees = new uint[](tokens.length);
    currentEscrow.tokens = new address[](tokens.length);
    currentEscrow.amounts = new uint[](tokens.length);

    if(currentEscrow.token_length > 0){
      for (uint i = 0; i < tokens.length; i++){
	currentEscrow.fees[i] = escrowFee*amounts[i]/1000;
	currentEscrow.tokens[i] = tokens[i];
	currentEscrow.amounts[i] = amounts[i];
	IERC20(tokens[i]).transferFrom(msg.sender, address(this), amounts[i]);
      }
    }
    currentEscrow.notes = notes;
    currentTransaction.buyer = msg.sender;
    currentTransaction.buyer_nounce = buyerDatabase[msg.sender].length;

    sellerDatabase[sellerAddress].push(currentTransaction);
    escrowDatabase.push(currentTransaction);
    buyerDatabase[msg.sender].push(currentEscrow);
            
    success = true;

  }

  function buyerFundRelease(uint ID) public{
    require(ID < buyerDatabase[msg.sender].length && 
            buyerDatabase[msg.sender][ID].release_approval == false &&
            buyerDatabase[msg.sender][ID].refund_approval == false);
            
    buyerDatabase[msg.sender][ID].release_approval = true;

    address seller = buyerDatabase[msg.sender][ID].seller;

    uint amount = buyerDatabase[msg.sender][ID].amount;
    uint escrow_fee = buyerDatabase[msg.sender][ID].escrow_fee;
    uint length = buyerDatabase[msg.sender][ID].token_length;
    address[] memory tokens = buyerDatabase[msg.sender][ID].tokens;
    uint[] memory amounts = buyerDatabase[msg.sender][ID].amounts;
    if(length > 0){
      for (uint i = 0; i < length; i++){
	IERC20(tokens[i]).transfer(seller,amounts[i]);
      }
    }
    address(uint160(seller)).transfer(amount);
    address(uint160(owner)).transfer(escrow_fee);

  }
  
  function sellerRefund(uint ID) public{
    address buyerAddress = sellerDatabase[msg.sender][ID].buyer;
    uint buyerID = sellerDatabase[msg.sender][ID].buyer_nounce;

    require(
            buyerDatabase[buyerAddress][buyerID].release_approval == false &&
            buyerDatabase[buyerAddress][buyerID].refund_approval == false); 

    uint escrow_fee = buyerDatabase[buyerAddress][buyerID].escrow_fee;
    uint amount = buyerDatabase[buyerAddress][buyerID].amount;
    uint length = buyerDatabase[buyerAddress][buyerID].token_length;
    address[] memory tokens = buyerDatabase[buyerAddress][buyerID].tokens;
    uint[] memory amounts = buyerDatabase[buyerAddress][buyerID].amounts;
    if(length > 0){
      for (uint i = 0; i < length; i++){
	IERC20(tokens[i]).transfer(buyerAddress,amounts[i]);
      }
    }
        
    buyerDatabase[buyerAddress][buyerID].refund_approval = true;

    address(uint160(buyerAddress)).transfer(amount);
    address(uint160(owner)).transfer(escrow_fee);
            
  }
  
  function EscrowEscalation(uint switcher, uint ID) public{
    address buyerAddress;
    uint buyerID;
    if (switcher == 0) {
      buyerAddress = msg.sender;
      buyerID = ID;
    } else if (switcher == 1) {
      buyerAddress = sellerDatabase[msg.sender][ID].buyer;
      buyerID = sellerDatabase[msg.sender][ID].buyer_nounce;
    }
    require(buyerDatabase[buyerAddress][buyerID].escrow_intervention == false  &&
            buyerDatabase[buyerAddress][buyerID].release_approval == false &&
            buyerDatabase[buyerAddress][buyerID].refund_approval == false);

    buyerDatabase[buyerAddress][buyerID].escrow_intervention = true;
  }

  function escrowDecision(uint ID, uint Decision) public {
    address buyerAddress = escrowDatabase[ID].buyer;
    uint buyerID = escrowDatabase[ID].buyer_nounce;
    require(
            buyerDatabase[buyerAddress][buyerID].release_approval == false &&
            buyerDatabase[buyerAddress][buyerID].escrow_intervention == true &&
            buyerDatabase[buyerAddress][buyerID].refund_approval == false);
            
    uint escrow_fee = buyerDatabase[buyerAddress][buyerID].escrow_fee;
    uint amount = buyerDatabase[buyerAddress][buyerID].amount;
    uint length = buyerDatabase[buyerAddress][buyerID].token_length;
    address[] memory tokens = buyerDatabase[buyerAddress][buyerID].tokens;
    uint[] memory amounts = buyerDatabase[buyerAddress][buyerID].amounts;

    if (Decision == 0) {
      buyerDatabase[buyerAddress][buyerID].refund_approval = true;    
      address(uint160(buyerAddress)).transfer(amount);
      msg.sender.transfer(escrow_fee);
      if(length > 0){
	for (uint i = 0; i < length; i++){
	  IERC20(tokens[i]).transfer(buyerAddress,amounts[i]);
	}
      }
                
    } else if (Decision == 1) {                
      buyerDatabase[buyerAddress][buyerID].release_approval = true;
      address(uint160(buyerDatabase[buyerAddress][buyerID].seller)).transfer(amount);
      msg.sender.transfer(escrow_fee);
      if(length > 0){
	for (uint i = 0; i < length; i++){
	  IERC20(tokens[i]).transfer(buyerDatabase[buyerAddress][buyerID].seller,amounts[i]);
	}
      }
      
    }  
  }
  
  function() payable external{
  
  }
  
  function getNumTransactions(address inputAddress, uint switcher) public view returns (uint len){
    if (switcher == 0) {
      len = buyerDatabase[inputAddress].length;
    } else if (switcher == 1) {
      len = sellerDatabase[inputAddress].length;
    }else{
      len = escrowDatabase.length;
    }
  }
  
  function getSpecificTransaction(address inputAddress, uint switcher, uint ID) public view returns (address[2] memory people, uint status , uint amount, uint fee, bytes32 notes, address[] memory tokens,uint[] memory amounts,uint[] memory fees)

  {
    EscrowStruct memory currentEscrow;
    if (switcher == 0) {
      currentEscrow = buyerDatabase[inputAddress][ID];
      status = checkStatus(inputAddress, ID);
    } else if (switcher == 1) {  
      currentEscrow = buyerDatabase[sellerDatabase[inputAddress][ID].buyer][sellerDatabase[inputAddress][ID].buyer_nounce];
      status = checkStatus(currentEscrow.buyer, sellerDatabase[inputAddress][ID].buyer_nounce);
    } else if (switcher == 2) {        
      currentEscrow = buyerDatabase[escrowDatabase[ID].buyer][escrowDatabase[ID].buyer_nounce];
      status = checkStatus(currentEscrow.buyer, escrowDatabase[ID].buyer_nounce);
    }

    people = [currentEscrow.buyer, currentEscrow.seller];
    amounts = currentEscrow.amounts;
    fees = currentEscrow.fees;
    tokens = currentEscrow.tokens;    
    amount = currentEscrow.amount;
    status = status;
    fee = currentEscrow.escrow_fee;
    notes = currentEscrow.notes;
  }

  function buyerHistory(address buyerAddress, uint startID, uint numToLoad) public view returns (address[] memory sellers ,uint[] memory amounts, uint[] memory statuses, address[][] memory tokens, uint[][] memory token_amounts, uint[][] memory fees){

    uint length;
    if (buyerDatabase[buyerAddress].length < numToLoad)
      length = buyerDatabase[buyerAddress].length;
    else 
      length = numToLoad;
            
    sellers = new address[](length);
    amounts = new uint[](length);
    statuses = new uint[](length);
    tokens = new address[][](length);
    token_amounts = new uint[][](length);
    fees = new uint[][](length);
    for (uint i = 0; i < length; i++)
      {
	sellers[i] = buyerDatabase[buyerAddress][startID + i].seller;
	amounts[i] = buyerDatabase[buyerAddress][startID + i].amount;
	tokens[i] = buyerDatabase[buyerAddress][startID + i].tokens;
	token_amounts[i] = buyerDatabase[buyerAddress][startID + i].amounts;
	fees[i] = buyerDatabase[buyerAddress][startID + i].fees;
	statuses[i] = checkStatus(buyerAddress, startID + i);
      }
  }
  
  function sellerHistory(address inputAddress, uint startID , uint numToLoad) public view returns (address[] memory buyers, uint[] memory amounts, uint[] memory statuses, address[][] memory tokens, uint[][] memory token_amounts, uint[][] memory fees){

    buyers = new address[](numToLoad);
    amounts = new uint[](numToLoad);
    statuses = new uint[](numToLoad);
    tokens = new address[][](numToLoad);
    token_amounts = new uint[][](numToLoad);
    fees = new uint[][](numToLoad);    

    for (uint i = 0; i < numToLoad; i++)
      {
	if (i >= sellerDatabase[inputAddress].length)
	  break;
	buyers[i] = sellerDatabase[inputAddress][startID + i].buyer;
	amounts[i] = buyerDatabase[buyers[i]][sellerDatabase[inputAddress][startID + i].buyer_nounce].amount;
	statuses[i] = checkStatus(buyers[i], sellerDatabase[inputAddress][startID + i].buyer_nounce);
	tokens[i] = buyerDatabase[buyers[i]][sellerDatabase[inputAddress][startID + i].buyer_nounce].tokens;
	fees[i] = buyerDatabase[buyers[i]][sellerDatabase[inputAddress][startID + i].buyer_nounce].fees;	
	token_amounts[i] = buyerDatabase[buyers[i]][sellerDatabase[inputAddress][startID + i].buyer_nounce].amounts;	
      }
  }

  function escrowHistory(uint startID, uint numToLoad) public view returns (address[] memory buyers, address[] memory sellers, uint[] memory amounts, uint[] memory statuses, address[][] memory tokens, uint[][] memory token_amounts, uint[][] memory fees){
        
    buyers = new address[](numToLoad);
    sellers = new address[](numToLoad);
    amounts = new uint[](numToLoad);
    statuses = new uint[](numToLoad);
    tokens = new address[][](numToLoad);
    token_amounts = new uint[][](numToLoad);
    fees = new uint[][](numToLoad);

    for (uint i = 0; i < numToLoad; i++)
      {
	if (i >= escrowDatabase.length)
	  break;
	buyers[i] = escrowDatabase[startID + i].buyer;
	sellers[i] = buyerDatabase[buyers[i]][escrowDatabase[startID +i].buyer_nounce].seller;
	amounts[i] = buyerDatabase[buyers[i]][escrowDatabase[startID + i].buyer_nounce].amount;
	statuses[i] = checkStatus(buyers[i], escrowDatabase[startID + i].buyer_nounce);
	tokens[i] = buyerDatabase[buyers[i]][escrowDatabase[startID + i].buyer_nounce].tokens;
	fees[i] = buyerDatabase[buyers[i]][escrowDatabase[startID + i].buyer_nounce].fees;	
	token_amounts[i] = buyerDatabase[buyers[i]][escrowDatabase[startID + i].buyer_nounce].amounts;
      }
  }
  
  function checkStatus(address buyerAddress, uint nounce) public view returns (uint status){
    if (buyerDatabase[buyerAddress][nounce].release_approval){
      status = 1;
    } else if (buyerDatabase[buyerAddress][nounce].refund_approval){
      status = 2;
    } else if (buyerDatabase[buyerAddress][nounce].escrow_intervention){
      status = 3;
    } else {
      status = 4;
    }
  }
  
  function getEscrowFee() public view returns (uint fee) {
    fee = escrowFee;
  }
  
}
