// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract CrowdFunding {

    address public manager;
    uint256 public deadline;
    uint256 public targetAmount;
    uint256 public currentCollection;

    mapping(address=>uint256) contributors;
    uint256 public totalContributors;

    //this flag is to check if target amount collected or not
    bool public crowdFundingSuccess;
    
    struct Request{
        uint id;
        string description;
        string url;
        uint amount;
        address payable recepient;
        mapping(address=>bool) voters;
        uint numOfVoters;
        bool completed;
    }

    uint256 requestId;
    mapping(uint256=>Request) public allRequests;

    event CrowFundingStart(address indexed manager, uint targetAmount, uint deadline);
    event CrowFundingSuccess(address indexed manager, uint targetAmount, uint collectedAmount);
    event NewRequest(address indexed manager, address indexed recepient, uint requestId, string description, string url, uint amount);
    event RequestCompleted(address indexed manager, address indexed recepient, uint requestId, string description, string url, uint amount);

    modifier onlyManager {
        require(msg.sender == manager, "Only manager can run this function");
        _;
    }

    constructor(uint _targetAmount, uint _deadline) {
        targetAmount = _targetAmount;
        deadline = block.timestamp + _deadline;
        manager = msg.sender;
        emit CrowFundingStart(manager, targetAmount, deadline);
    }

    function contribute() external payable{
        require(block.timestamp < deadline, "Deadline has passed for the crowd funcding!!");
        require(msg.value>0, "Please send some amount.");
        require(crowdFundingSuccess==false, "target amount already acheived");

        if(contributors[msg.sender] == 0){
            totalContributors++;
        }
        currentCollection += msg.value;
        contributors[msg.sender] += msg.value;
        if(currentCollection >= targetAmount){
            crowdFundingSuccess=true;
            emit CrowFundingSuccess(manager, targetAmount, currentCollection);
        }
    }

    function getCurrentCollection() external view returns(uint256 fundsCollected){
        return address(this).balance;
    }

    function createRequest(string calldata _description, string calldata _url, address payable _recepient, uint _amount) external onlyManager{
        require(_amount > 0 && _amount <= currentCollection, "amount should be greater than 0 and less than current collection.");
        require(crowdFundingSuccess==true , "Crowd funding not successfully completed");

        Request storage request = allRequests[requestId];
        request.id = requestId;
        request.description = _description;
        request.recepient = _recepient;
        request.amount = _amount;
        request.url = _url;
        emit NewRequest(manager, _recepient, requestId, _description, _url, _amount);
        requestId++;
    }

    function refund() external {
        
        require(crowdFundingSuccess == false, "Crowdfunding successfully completed. Cant refund.");
        require(block.timestamp > deadline, "Crowdfunding still going on.");
        require(contributors[msg.sender]>0, "You have not contributed to this crowd funding.");

        contributors[msg.sender] = 0;
        currentCollection-=contributors[msg.sender];
        (bool sent,) = payable(msg.sender).call{value: contributors[msg.sender]}("");
        require(sent,"Failed to refund");
    }

    function supportRequest(uint _requestId) external {
        Request storage request = allRequests[_requestId];
        require(request.amount>0, "This is invalid request");
        require(contributors[msg.sender]>0, "You cant vote as you are not a contributor.");
        require(request.completed ==false, "Already completed");
        require(request.voters[msg.sender] ==false, "You have already voted for this request");

        request.voters[msg.sender] = true;
        request.numOfVoters++;

    }

    function getCurrentSupportPercentage(uint _requestId) external view returns(uint supportPercentage){
        Request storage request = allRequests[_requestId];
        require(request.amount > 0, "Invalid request");

        return (request.numOfVoters*100)/totalContributors;

    }

    function makePayment(uint _requestId) external onlyManager {
        Request storage request = allRequests[_requestId];
        require(request.amount > 0, "Invalid request");
        require(request.completed ==false, "Already completed");
        require(request.numOfVoters > totalContributors/2, "Not enough support for this request.");
        request.completed = true;
        currentCollection-=request.amount;
        (bool sent,) = payable(msg.sender).call{value: request.amount}("");
        require(sent == true, "Failed to transfer");
        emit RequestCompleted(manager, request.recepient, request.id, request.description, request.url, request.amount);
    }

}