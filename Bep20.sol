// SPDX-License-Identifier: MIT


/* 
    Author: SHAIKH HUSSAIN

    NOTE: This contracts are offered for learning purposes only, to illustrate certain aspects of development regarding web3, 
   they are not audited and not to use in any production environment.
 */

/*    __                         ________               __ 
   / /   ____ _____  __  __   / ____/ /_  ____  _____/ /_
  / /   / __ `/_  / / / / /  / / __/ __ \/ __ \/ ___/ __/
 / /___/ /_/ / / /_/ /_/ /  / /_/ / / / / /_/ (__  ) /_  
/_____/\__,_/ /___/\__, /   \____/_/ /_/\____/____/\__/  
                  /____/                                 
    _   ______________    
   / | / / ____/_  __/____
  /  |/ / /_    / / / ___/
 / /|  / __/   / / (__  ) 
/_/ |_/_/     /_/ /____/  
 */

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract LazyMint is ERC721, ERC721URIStorage, Ownable, EIP712, AccessControl {

    error OnlyMinter(address to);
    error NotEnoughValue(address to, uint256);
    error NoFundsToWithdraw(uint256 balance);
    error FailedToWithdraw(bool sent);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string private constant SIGNING_DOMAIN = "Lazy-Domain";
    string private constant SIGNING_VERSION = "1";

    event NewMint(address indexed to, uint256 tokenId);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    struct LazyMintVoucher{
        uint256 tokenId;
        uint256 price;
        string uri;
        bytes signature;
    }

    constructor(address minter) ERC721("LazyMint", "MTK") EIP712(SIGNING_DOMAIN, SIGNING_VERSION) {
        _setupRole(MINTER_ROLE, minter);
    }
    

    function mintNFT(address _to, LazyMintVoucher calldata _voucher) public payable {
        address signer = _verify(_voucher);
        if(hasRole(MINTER_ROLE, signer)){
            if(msg.value >= _voucher.price){
                _safeMint(_to, _voucher.tokenId);
                _setTokenURI(_voucher.tokenId, _voucher.uri);
                emit NewMint(_to, _voucher.tokenId);
            }else{
                revert NotEnoughValue(_to, msg.value);
            }
        }else{
            revert OnlyMinter(_to);
        }
    }

    function _hash(LazyMintVoucher calldata voucher) internal view returns(bytes32){
        return _hashTypedDataV4(keccak256(abi.encode(
            //function selector
            keccak256("LazyMintVoucher(uint256 tokenId,uint256 price,string uri)"),
            voucher.tokenId,
            voucher.price,
            keccak256(bytes(voucher.uri))
        )));
    }

    function _verify(LazyMintVoucher calldata voucher) internal view returns(address){
        bytes32 digest = _hash(voucher);
        //returns signer
        return ECDSA.recover(digest, voucher.signature);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721) returns (bool){
        return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    function withdrawFunds() public onlyOwner{
        uint256 balance = address(this).balance;
        if(balance <= 0){revert NoFundsToWithdraw(balance);}
        (bool sent,) = msg.sender.call{value: balance}("");
        if(!sent){revert FailedToWithdraw(sent);}
        emit FundsWithdrawn(msg.sender, balance);
    }
}
