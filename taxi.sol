pragma solidity   >=0.4.22 <0.7.0;
contract TaxiContract{
    
                                    //STATE VARIABLES
    
    struct Participant{
        address payable p_address;
        uint p_balance;   
    }
    
    struct Dealer{
        address payable car_dealer;
        bool buy_car;
        bool sell_car;
        uint maintenance_tax_time;               //every six month   
    }
    
    struct Driver{
        address payable taxi_driver;
        uint driver_salary;
        uint salary_time;              //every month
        bool driver_assigned;
        
        //as we did while chosing car we need the mapping and approve state
        uint approve_counter;
        mapping (address=>bool) driver_votes;
        
    }
    
    struct ProposedCar{
        uint32 car_id;      //32 bit Owned car id
        uint car_price;
        uint offer_valid_time;
        uint approval_state; //when it is more than half of the participant sell or buy
        mapping (address=>bool) approve_votes;
               
    }
    
    uint fix_ed_expenses;           //fixed can not written look at here next day
    uint participation_fee;         //needs to pay to enter taxi business
    
    address  payable manager;                  //manager
    uint manager_six_months;
    
    Participant [] participants;
    Dealer dealer;
    Driver driver;
    Driver proposed_driver;
    
    ProposedCar car1;
    ProposedCar repurchase_car;
    
    constructor () public payable {
        manager=msg.sender;               //manager assigned
        fix_ed_expenses =10 ether;
        participation_fee = 10 ether;
        manager_six_months=now;
    }
    
                                    //Modifiers
                            
    modifier onlyManager{
        require(msg.sender==manager);
        _;
    }
    modifier onlyParticipant(){
        require(msg.sender!=manager);
        require(msg.sender!=dealer.car_dealer);
        require(msg.sender!=driver.taxi_driver);
        _;
    }
    modifier onlyDealer{
        require(msg.sender==dealer.car_dealer);
        _;
    }
    modifier onlyDriver{
        require(msg.sender==driver.taxi_driver);
        _;
    }
    modifier afterSixMonth(){               //for car_dealer maintenance_tax_time
        require(now> (180 days + dealer.maintenance_tax_time));
        _;
    }
    modifier afterOneMonth(){                               //for salary_time
        require(now> (30 days +driver.salary_time));
        _;
    }
    modifier managerSixMCalculator(){                   //for manager PayDividend
        require(now>180 days +manager_six_months);
        _;
    }
    
    
                                    //Functions
                                    
    function Join() public payable onlyParticipant {
        require(participants.length<9,"No more member allowed.");
        require(msg.value>=participation_fee,"Not enough ether to join.");
        
        bool duplicateControl=false;
        for (uint _i=0;_i<participants.length;_i++){             //to detect duplicate participant
            if (msg.sender == participants[_i].p_address){
                duplicateControl=true;
                break;
            }
        }
        require(!duplicateControl,"You have already participated.");
        address(this).transfer(msg.value);
        participants.push(Participant({p_address:msg.sender,p_balance:0}));
        
    }
    function SetCarDealer(address payable _car_dealer) public payable onlyManager { //be carefull account on remix must be manager and parameter can not be manager
        dealer=Dealer({
            car_dealer:_car_dealer,
            buy_car:true,
            sell_car:false,
            maintenance_tax_time:0  //will be assigned when car the car will be purchased
        });
    }
    
    function CarProposeToBusiness(uint32 _car_id, uint _car_price) public payable onlyDealer{
        //as stated previous first assign Account on remix deploy panel to dealer then this will work.
        car1= ProposedCar({
        car_id: _car_id,
        car_price: _car_price,
        offer_valid_time: now + (10 days),
        approval_state: 0
        });
        dealer.buy_car=true;
    }
    
    function ApprovePurchaseCar() public payable onlyParticipant{
        //change account to a participant.
        require(dealer.buy_car,"There is no car to vote");
        require(car1.approve_votes[msg.sender]==false,"You have already voted");
        //require(car1.offer_valid_time>now,"Car voting is out of date");  //remove this because can expire
        
        if (car1.offer_valid_time<now){                 //if the valid time expired remove all votes 
            for (uint _i=0;_i<participants.length;_i++){
                delete car1.approve_votes[participants[_i].p_address];
            }
            car1.approval_state=0;
        }else{                                          //otherwise continue increment
            car1.approve_votes[msg.sender]=true;
            car1.approval_state++;
        }
    }
    
    function PurchaseCar() public payable onlyManager{
        require(dealer.buy_car,"There is no car to purchase");
        if (car1.offer_valid_time<now){                     //control valid time 
            for (uint _i=0;_i<participants.length;_i++){
                delete car1.approve_votes[participants[_i].p_address];
            }
            car1.approval_state=0;
        }
        require(car1.approval_state> (participants.length) / 2, "Majority did not accept to purchase car.");
        
        //control balance of the contract
        require(address(this).balance >= car1.car_price," Not enough money on contract"); 
        
        //manager is responsible for the contract money
        dealer.car_dealer.transfer(car1.car_price);
        
        //now we have car so we can not buy but sell 
        //so assign them 
        
        dealer.buy_car=false;//we can not buy
        dealer.maintenance_tax_time= now + (30 days);
        
        //set the car values to initial values just for below
        
        car1.offer_valid_time=0;
        car1.approval_state=0;
        for (uint _i=0;_i<participants.length;_i++){
            delete car1.approve_votes[participants[_i].p_address];
        }
    }
    
    function RepurchaseCarPropose(uint _car_price) public payable onlyDealer{
        require(msg.value>=_car_price,"Not enough money to repurchase the car");
        
        repurchase_car=ProposedCar({
        car_id: car1.car_id,        //we are selling our car 
        car_price: _car_price,      //cost has already decided externally
        offer_valid_time: now + (10 days),
        approval_state: 0
        });
        
        dealer.sell_car=true;//contract will let
    }
    
    function ApproveSellProposal() public payable onlyParticipant{
        //same ops will be done in ApprovePurchaseCar
        require(dealer.sell_car,"There is no car to sell to dealer.");
        require(repurchase_car.approve_votes[msg.sender]==false,"You have already voted.");
        
        if (repurchase_car.offer_valid_time<now){//delete each of the voters as before done
            for (uint _i=0;_i<participants.length;_i++){
                delete repurchase_car.approve_votes[participants[_i].p_address];
            }
        }else{
            repurchase_car.approve_votes[msg.sender]=true;
            repurchase_car.approval_state++;
        }
    }
    
    function Repurchasecar() public payable onlyDealer{
        require(dealer.sell_car,"There is no car to sell to dealer");
        if (repurchase_car.offer_valid_time<now){                     //control valid time 
            for (uint _i=0;_i<participants.length;_i++){
                delete repurchase_car.approve_votes[participants[_i].p_address];
            }
            repurchase_car.approval_state=0;
        }
        require(repurchase_car.approval_state> (participants.length) / 2, "Majority did not accept to sell the car.");
        
        //control balance of the dealer
        require(msg.value >= repurchase_car.car_price," Not enough money on contract"); 
        
        //transfer money from dealer to the contract 
        address(this).transfer(msg.value);
        
        
        dealer.sell_car=false;// contract can not sell any car
        dealer.maintenance_tax_time=0;// no maintenance_tax_time;
        
        //set the car values to inital values
        //but we know that we have to buy car so no need to assign the car values now
        //car values will be assign when the  CarProposeToBusiness called.
    }
    
    function ProposeDriver(address payable _driver,uint _salary) public payable onlyManager{
        
        //temp driver holds in here when it is selected it will be driver.
        
        require(!driver.driver_assigned,"There is already a taxi driver, can not propose driver");
        proposed_driver= Driver({
            taxi_driver: _driver,
            driver_salary:_salary,
            driver_assigned:true,       //we assume that for now
            salary_time:now,
            approve_counter:0
        });
    }
    
    function ApproveDriver() public payable onlyParticipant {
        require( !driver.driver_assigned,"There is already a taxi driver, can not approve driver.");
        require(  proposed_driver.driver_assigned,"Proposed driver do not exist.");
        require(  proposed_driver.driver_votes[msg.sender]==false,"You have already voted");
        
        proposed_driver.driver_votes[msg.sender]=true;
        proposed_driver.approve_counter++;
    }
    
    function SetDriver() public payable onlyManager{
        require( !driver.driver_assigned,"There is already a taxi driver, can not set driver.");
        require(  proposed_driver.driver_assigned,"Proposed driver do not exist.");
        
        require(proposed_driver.approve_counter> (participants.length)/2,"Majority did not accept the proposed driver");
        
        driver= Driver({
            taxi_driver:proposed_driver.taxi_driver,
            driver_salary:proposed_driver.driver_salary,
            driver_assigned:true,
            salary_time:proposed_driver.salary_time,
            approve_counter:proposed_driver.approve_counter
        });
        
        for (uint _i=0;_i<participants.length;_i++){//remove all votes for the next voting operations
            delete proposed_driver.driver_votes[participants[_i].p_address];
        }
        delete proposed_driver;         //temp car driver is removed 
    }   
    
    function FireDriver() public payable onlyManager{
        require(driver.driver_assigned,"There is no driver. can not fire");
        require(address(this).balance>= driver.driver_salary,"Not enough money on the contract you can not fire.");
        
        driver.taxi_driver.transfer(driver.driver_salary);
        
        // our job to fire just turn driver.driver_assigned value to false 
        //now we have no driver assigned to a car
        // no need to remove address of driver because we will change we approve new driver
        
        driver.driver_assigned=false;
        driver.approve_counter=0;
    }
    
    function PayTaxiCharge() public payable {
        require(driver.driver_assigned,"There is no driver, you can not pay taxi charge");
        require(msg.value>0,"Not enough money to pay taxi charge");
        
        address(this).transfer(msg.value);// send it to the contract
        
    }
    
    function ReleaseSalary () public payable onlyManager afterOneMonth{
        //only manager and after one month is calculated at modifier
        require(driver.driver_assigned,"There is no driver");
        require(address(this).balance>=driver.driver_salary,"Not enough money on contract");
        
        driver.taxi_driver.transfer(driver.driver_salary);
        driver.salary_time+= 30 days;   // next salary_time is assigned
    }
    
    function GetSalary() public view onlyDriver returns(uint){
        
        //driver money already pay the salary on ReleaseSalary function
        return driver.taxi_driver.balance;
    }
    
    function PayCarExpenses() public payable 
    onlyManager 
    afterSixMonth                   //to see more clear the modifiers
    {
        
        //only manager and after six months is calculated at modifiers
        
        dealer.car_dealer.transfer(fix_ed_expenses);
        dealer.maintenance_tax_time +=  180 days;
        
    }
    
    function PayDividend() public payable 
    onlyManager 
    managerSixMCalculator
    {
        // do not need to calculate months they are calculated at called functions.
        
        if (now> (180 days + dealer.maintenance_tax_time)){// to avoid from require exception
            PayCarExpenses();
        }
        if (now> (30 days + driver.salary_time)){
            ReleaseSalary();
        }
        //after calculating expenses calcute profit.
        
        uint unit_profit=showBalances() / participants.length;
        for (uint _i=0;_i<participants.length;_i++){
            participants[_i].p_balance+=unit_profit;
        }
        
        manager_six_months+=180 days;
        
        // we are not reduce contract balance now.
        //it will reduce when each participants call GetDividend 
    }
    
    
    function GetDividend()public payable onlyParticipant{
        //first find the participant in the array.
        uint participant_counter=0;
        for (uint _i=0;_i<participants.length;_i++){
            if (msg.sender==participants[_i].p_address){
                participant_counter=_i;
                break;
            }
        }
        require(msg.sender==participants[participant_counter].p_address,"There is no participant at this address");
        msg.sender.transfer(participants[participant_counter].p_balance);
        
    }
    
    function showBalances() public view returns (uint ) {
        return address(this).balance;
    }
    
    fallback () external payable { 
        //revert(); // reverts state to before call
        //remove revert or change compiler 
    }
        
}