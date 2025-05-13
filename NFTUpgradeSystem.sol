// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract NFTUpgradeSystem is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;

    // NFT Traits structure
    struct Traits {
        uint256 strength;
        uint256 speed;
        uint256 intelligence;
        uint256 rarity;
        string visualAppearance; // Could be a CID for IPFS or on-chain SVG
    }

    // Mapping from token ID to traits
    mapping(uint256 => Traits) private _tokenTraits;

    // Mapping from token ID to merge count
    mapping(uint256 => uint256) private _mergeCount;

    // Cost to merge NFTs (in wei)
    uint256 public mergeFee = 0.01 ether;

    // Events
    event NFTsMerged(
        uint256 indexed newTokenId,
        uint256 indexed tokenId1,
        uint256 indexed tokenId2,
        Traits newTraits
    );
    event MergeFeeUpdated(uint256 newFee);

    constructor() ERC721("UpgradeableNFT", "UNFT") Ownable(msg.sender) {}

    // Mint a new NFT with random traits
    function mintNFT(address to) public payable returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        // Generate random traits (for demo purposes)
        Traits memory newTraits = Traits({
            strength: uint256(keccak256(abi.encodePacked(block.timestamp, tokenId, "strength"))) % 100,
            speed: uint256(keccak256(abi.encodePacked(block.timestamp, tokenId, "speed"))) % 100,
            intelligence: uint256(keccak256(abi.encodePacked(block.timestamp, tokenId, "intelligence"))) % 100,
            rarity: uint256(keccak256(abi.encodePacked(block.timestamp, tokenId, "rarity"))) % 100,
            visualAppearance: generateVisualAppearance(tokenId)
        });

        _tokenTraits[tokenId] = newTraits;
        _safeMint(to, tokenId);

        return tokenId;
    }

    // Merge two NFTs to create a new one with combined traits
    function mergeNFTs(uint256 tokenId1, uint256 tokenId2) public payable returns (uint256) {
        require(msg.value >= mergeFee, "Insufficient merge fee");
        require(ownerOf(tokenId1) == msg.sender && ownerOf(tokenId2) == msg.sender, "Not owner of both tokens");
        require(tokenId1 != tokenId2, "Cannot merge same token");

        // Burn the original tokens
        _burn(tokenId1);
        _burn(tokenId2);

        // Create new token with combined traits
        uint256 newTokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        Traits memory traits1 = _tokenTraits[tokenId1];
        Traits memory traits2 = _tokenTraits[tokenId2];

        // Calculate new traits (weighted average favoring higher values)
        Traits memory newTraits = Traits({
            strength: calculateCombinedTrait(traits1.strength, traits2.strength),
            speed: calculateCombinedTrait(traits1.speed, traits2.speed),
            intelligence: calculateCombinedTrait(traits1.intelligence, traits2.intelligence),
            rarity: calculateCombinedTrait(traits1.rarity, traits2.rarity),
            visualAppearance: generateVisualAppearance(newTokenId)
        });

        _tokenTraits[newTokenId] = newTraits;
        _mergeCount[newTokenId] = _mergeCount[tokenId1] + _mergeCount[tokenId2] + 1;
        _safeMint(msg.sender, newTokenId);

        emit NFTsMerged(newTokenId, tokenId1, tokenId2, newTraits);
        return newTokenId;
    }

    // Helper function to calculate combined trait (weighted average)
    function calculateCombinedTrait(uint256 trait1, uint256 trait2) internal pure returns (uint256) {
        uint256 maxTrait = trait1 > trait2 ? trait1 : trait2;
        uint256 minTrait = trait1 > trait2 ? trait2 : trait1;
        
        // Weighted average (60% higher trait, 40% lower trait) + 5% boost
        return ((maxTrait * 6 + minTrait * 4) / 10) * 105 / 100;
    }

    // Generate visual appearance (on-chain SVG for demo)
    function generateVisualAppearance(uint256 tokenId) internal view returns (string memory) {
        Traits memory traits = _tokenTraits[tokenId];
        string memory svg = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400">',
            '<rect width="400" height="400" fill="#', uintToColorHex(traits.strength), '"/>',
            '<circle cx="200" cy="200" r="150" fill="#', uintToColorHex(traits.speed), '"/>',
            '<polygon points="200,50 350,350 50,350" fill="#', uintToColorHex(traits.intelligence), '"/>',
            '<text x="200" y="380" font-family="Arial" font-size="24" fill="white" text-anchor="middle">',
            'Merges: ', _mergeCount[tokenId].toString(), '</text>',
            '</svg>'
        ));
        
        return string(abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(bytes(svg))
        );
    }

    // Helper function to convert uint to color hex
    function uintToColorHex(uint256 value) internal pure returns (string memory) {
        uint256 colorValue = value % 16777215; // Limit to 24-bit color
        bytes memory colorBytes = bytes.concat(
            bytes1(uint8(colorValue >> 16)),
            bytes1(uint8(colorValue >> 8)),
            bytes1(uint8(colorValue))
        );
        return bytesToHex(colorBytes);
    }

    // Helper function to convert bytes to hex
    function bytesToHex(bytes memory buffer) internal pure returns (string memory) {
        bytes memory hexTable = "0123456789abcdef";
        bytes memory hexBuffer = new bytes(buffer.length * 2);
        
        for (uint256 i = 0; i < buffer.length; i++) {
            hexBuffer[i*2] = hexTable[uint8(buffer[i]) >> 4];
            hexBuffer[i*2+1] = hexTable[uint8(buffer[i]) & 0x0f];
        }
        
        return string(hexBuffer);
    }

    // Get token URI with metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        Traits memory traits = _tokenTraits[tokenId];
        string memory image = traits.visualAppearance;
        
        string memory json = Base64.encode(bytes(abi.encodePacked(
            '{"name": "Upgradeable NFT #', tokenId.toString(), '",',
            '"description": "An NFT that can be merged with others to upgrade its traits.",',
            '"image": "', image, '",',
            '"attributes": [',
            '{"trait_type": "Strength", "value": ', traits.strength.toString(), '},',
            '{"trait_type": "Speed", "value": ', traits.speed.toString(), '},',
            '{"trait_type": "Intelligence", "value": ', traits.intelligence.toString(), '},',
            '{"trait_type": "Rarity", "value": ', traits.rarity.toString(), '},',
            '{"trait_type": "Merge Count", "value": ', _mergeCount[tokenId].toString(), '}',
            ']}'
        )));
        
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    // Owner functions
    function setMergeFee(uint256 newFee) public onlyOwner {
        mergeFee = newFee;
        emit MergeFeeUpdated(newFee);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
