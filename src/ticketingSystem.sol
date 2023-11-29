// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {console} from "forge-std/Test.sol";

contract TicketingSystem {
    struct artist {
        bytes32 name;
        uint256 artistCategory;
        address payable owner;
        uint256 totalTicketSold;
    }
    struct venue {
        bytes32 name;
        uint256 capacity;
        uint256 venueCommission;
        address payable owner;
    }
    struct concert {
        uint256 artistId1;
        uint256 venueId1;
        uint256 concertDate1;
        uint256 ticketPrice1;
        bool validatedByArtist1;
        bool validatedByVenue1;
        uint256 totalTicketSold1;
        uint256 totalMoneyCollected1;
    }
    struct ticket {
        uint256 concertId;
        address payable owner;
        bool isAvailable;
        bool isAvailableForSale;
        uint256 amountPaid;
    }

    //Counts number of artists created
    uint256 public artistCount = 0;
    //Counts the number of venues
    uint256 public venueCount = 0;
    //Counts the number of concerts
    uint256 public concertCount = 0;
    uint256 public ticketCount = 0;

    //MAPPINGS & ARRAYS
    mapping(uint256 => artist) public artistsRegister;
    mapping(bytes32 => uint256) private artistsID;
    mapping(uint256 => venue) public venuesRegister;
    mapping(bytes32 => uint256) private venuesID;
    mapping(uint256 => concert) public concertsRegister;
    mapping(uint256 => ticket) public ticketsRegister;

    //EVENTS
    event CreatedArtist(bytes32 name, uint256 id);
    event ModifiedArtist(bytes32 name, uint256 id, address sender);
    event CreatedVenue(bytes32 name, uint256 id);
    event ModifiedVenue(bytes32 name, uint256 id);
    event CreatedConcert(uint256 concertDate, bytes32 name, uint256 id);

    function createArtist(bytes32 _artistName, uint256 _artistCategory) public {
        artistCount++;
        artistsRegister[artistCount] = artist(_artistName,_artistCategory, payable(msg.sender),0);
    }
    function modifyArtist(uint _artistId, bytes32 _name, uint _artistCategory, address payable _newOwner) public {
        require (payable(msg.sender)==artistsRegister[_artistId].owner,"not the owner");
        uint256 currentTotalTicketSold = artistsRegister[_artistId].totalTicketSold;
        artistsRegister[_artistId] = artist(_name,_artistCategory, _newOwner,currentTotalTicketSold);
    }
    function createVenue(bytes32 _name, uint256 _capacity, uint256 _standardComission) public {
        venueCount++;
        venuesRegister[venueCount] = venue(_name,_capacity, _standardComission, payable(msg.sender));
    }
    function modifyVenue(
        uint256 _venueId,
        bytes32 _name,
        uint256 _capacity,
        uint256 _standardComission,
        address payable _newOwner) public {
            require (payable(msg.sender)==venuesRegister[_venueId].owner,"not the venue owner");
            venuesRegister[_venueId] = venue(_name,_capacity,_standardComission,_newOwner);
        }
    //FUNCTIONS TEST 3 -- CONCERTS
    function createConcert(uint256 _artistId, uint256 _venueId, uint256 _concertDate, uint256 _ticketPrice) public {
        concertCount++;
        bool validatedByArtist1 = false;
        bool validatedByVenue1 = false;
        if (payable(msg.sender) == artistsRegister[_artistId].owner) {
            validatedByArtist1 = true;
        }
        if (payable(msg.sender) == venuesRegister[_venueId].owner) {
            validatedByVenue1 = true;
        }
        concertsRegister[concertCount] = concert(_artistId,_venueId,_concertDate,_ticketPrice,validatedByArtist1,validatedByVenue1,0,0);
    }

    function validateConcert(uint256 _concertId) public {
        concert storage concertTemp = concertsRegister[_concertId];

        if (artistsRegister[concertTemp.artistId1].owner == payable(msg.sender)) {
            concertTemp.validatedByArtist1 = true;
        }
        if (venuesRegister[concertTemp.venueId1].owner == payable(msg.sender)) {
            concertTemp.validatedByVenue1 = true;
        }
    }

    //Creation of a ticket, only artists can create tickets
    function emitTicket(uint256 _concertId, address payable _ticketOwner) public {
        concert storage concertTemp = concertsRegister[_concertId];
        require(artistsRegister[concertTemp.artistId1].owner == payable(msg.sender),"not the owner");
        concertTemp.totalTicketSold1++;

        ticketCount++;
        ticketsRegister[ticketCount] = ticket(_concertId,_ticketOwner, true, false,0);
    }

    function useTicket(uint256 _ticketId) public {
        ticket storage ticketTemp = ticketsRegister[_ticketId];
        require(payable(msg.sender)==ticketTemp.owner,"sender should be the owner");
        require(concertsRegister[ticketTemp.concertId].concertDate1 <= block.timestamp + 60*60*24,"should be used the d-day");
        require(concertsRegister[ticketTemp.concertId].validatedByVenue1 == true,"should be validated by the venue");
        ticketTemp.isAvailable = false;
        ticketTemp.owner = payable(address(0));
    }

    //FUNCTIONS TEST 4 -- BUY/TRANSFER
    function buyTicket(uint256 _concertId) public payable {
        require(concertsRegister[_concertId].ticketPrice1 == msg.value,"not the right price");
        concertsRegister[_concertId].totalTicketSold1++;
        concertsRegister[_concertId].totalMoneyCollected1 += msg.value;
        // Emit the ticket
        ticketCount++;
        ticketsRegister[ticketCount] = ticket(_concertId, payable(msg.sender), true, false, msg.value);
    }

    function transferTicket(uint256 _ticketId, address payable _newOwner) public {
        require(payable(msg.sender)==ticketsRegister[_ticketId].owner,"not the ticket owner");
        ticketsRegister[_ticketId].owner = _newOwner;
    }
    //FUNCTIONS TEST 5 -- CONCERT CASHOUT
    function cashOutConcert(uint256 _concertId, address payable _cashOutAddress) public {
        require(block.timestamp >= concertsRegister[_concertId].concertDate1,"should be after the concert");
        require(artistsRegister[concertsRegister[_concertId].artistId1].owner == msg.sender, "should be the artist");
        
        uint256 totalTicketSales = concertsRegister[_concertId].ticketPrice1 * concertsRegister[_concertId].totalTicketSold1;
        uint256 venueShare = (totalTicketSales * venuesRegister[concertsRegister[_concertId].venueId1].venueCommission) / 10000;
        uint256 artistShare = totalTicketSales - venueShare;

        _cashOutAddress.call{value: artistShare}("");
        venuesRegister[concertsRegister[_concertId].venueId1].owner.call{value: venueShare}("");

        artistsRegister[concertsRegister[_concertId].artistId1].totalTicketSold += concertsRegister[_concertId].totalTicketSold1;
    }
    //FUNCTIONS TEST 6 -- TICKET SELLING
    function offerTicketForSale(uint256 _ticketId, uint256 _salePrice) public {
        ticket storage ticketTemp = ticketsRegister[_ticketId];
        require(payable(msg.sender) == ticketTemp.owner, "should be the owner");
        require(_salePrice <= ticketTemp.amountPaid, "should be less than the amount paid");
        ticketTemp.isAvailableForSale = true;
        ticketTemp.amountPaid = _salePrice;
    }

    function buySecondHandTicket(uint256 _ticketId) public payable {
        ticket storage ticketTemp = ticketsRegister[_ticketId];
        require(ticketTemp.isAvailable, "should be available");
        require(msg.value >= ticketTemp.amountPaid, "not enough funds");

        address payable previousOwner = ticketTemp.owner;
        ticketTemp.owner = payable(msg.sender);

        previousOwner.call{value: ticketTemp.amountPaid}("");

        ticketTemp.isAvailableForSale = false;
        ticketTemp.amountPaid = 0; 
    }
}