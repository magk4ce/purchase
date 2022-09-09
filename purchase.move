address 0x2{
// ---------------------------purchase moduel----------------------
    module Purchase{
        use std::signer;
        use std::vector;
        use std::debug;

        //Goods stauts. AVAIABLE:ready to sell. CLOSED:not on shelf. 
        const AVAILABLE:u64=1;
        const CLOSED:u64=2;
        const SOLD:u64=0;
        
        // regists all non-empty market addresses
        struct AddrBook has key,store{
            mktAddresses:vector<address>,
        }
        struct Goods has store,copy,drop{
            index:u64,
            status:u64,
            price:u64,
            seller:address,
            buyer:vector<address>,
        }

        struct Market<Goods> has key,store{
            goods_list:vector<Goods>,
        }

        // only admin address could init address book
        fun admin_address():address{
            @0x2
        }

        // init address book
        public fun init_addr_book(account:&signer){
            let addr=signer::address_of(account);
            assert!(admin_address()==addr,0000);
            move_to(account,AddrBook{
                mktAddresses:vector::empty<address>()
            });
        }

        fun add_to_addrbook(mktAddr:address):u64 acquires AddrBook{
            let addrbook=borrow_global_mut<AddrBook>(admin_address());
            let addrs=&mut addrbook.mktAddresses;
            vector::push_back(addrs,mktAddr);
            vector::length(addrs)
        }

        fun remove_from_addrbook(mktAddr:address):u64 acquires AddrBook,Market{
            //Remove a Market with non-empty goods_list is not allowed.
            let mkt=borrow_global_mut<Market<Goods>>(mktAddr);
            let goods_list=&mkt.goods_list;
            assert! (vector::length(goods_list) == 0,20000);

            let addrbook=borrow_global_mut<AddrBook>(admin_address());
            let addrs=&mut addrbook.mktAddresses;
            let (found,i)=vector::index_of(addrs,&mktAddr);
            assert!(found,2001);
            vector::remove(addrs,i);
            vector::length(addrs)
        }
        
        fun init_market(account:&signer) acquires AddrBook{
            move_to(account,Market{
                goods_list:vector::empty<Goods>()
            });
            add_to_addrbook(signer::address_of(account));
        }

        // publish goods
        public fun publish(account:&signer,price:u64):u64 acquires Market,AddrBook{
            let addr=signer::address_of(account);
            if (!exists<Market<Goods>>(addr)) {
                init_market(account);
                };
            let mkt= borrow_global_mut<Market<Goods>>(addr);
            let len= vector::length(&mkt.goods_list);
            // generate a goods
            let goods=Goods{
                            index:len,
                            status:AVAILABLE,
                            price:price,
                            seller:addr,
                            buyer:vector::empty<address>(),
                            } ;
            // put goods into vector goods_list
            vector::push_back<Goods>(&mut mkt.goods_list,goods);
            vector::length(&mkt.goods_list)
        }
        // Put goods in goods_list on shelf.
        public fun publish_existing_goods(account:&signer,index:u64,price:u64) acquires Market{
            let addr=signer::address_of(account);
            assert !(exists<Market<Goods>>(addr),1000);
            let market=borrow_global_mut<Market<Goods>>(addr);
            let goods_list =&mut market.goods_list; 
            let len:u64=vector::length(goods_list);
            assert!(index>=0,1000);
            assert!(len>index,1000);

            let goods= vector::borrow_mut<Goods>(goods_list,index);
            goods.status=AVAILABLE;
            goods.price=price;
            goods.seller=addr;
        }

        // Buy a goods according to its market address and order
        public fun order(account:&signer,deposit:u64,mktAddr:address,index:u64) acquires Market,AddrBook{
            let buyerAddr=signer::address_of(account);
            if (buyerAddr == mktAddr) return;
            assert!(exists<Market<Goods>>(mktAddr),1000);
            let mkt= borrow_global_mut<Market<Goods>>(mktAddr);
            let goods_list=&mut mkt.goods_list;
            assert!(index>=0,1000);
            assert!(vector::length(goods_list)>=index,1000);
            let goods_ref_mut=vector::borrow_mut<Goods>(goods_list,index);
            assert!(goods_ref_mut.status==AVAILABLE,1000);
            if (deposit>=goods_ref_mut.price*2) {
                vector::push_back<address>(&mut goods_ref_mut.buyer,buyerAddr);
                let new_goods= *goods_ref_mut;
                goods_ref_mut.status=SOLD;
                let Goods{index:_,status:_,price:_,seller:_,buyer:_}= vector::pop_back<Goods>(goods_list);
                if (vector::length(goods_list)==0) {remove_from_addrbook(mktAddr);};                  
                if (!exists<Market<Goods>>(buyerAddr)) init_market(account);
                let buyerMkt=borrow_global_mut<Market<Goods>>(buyerAddr);
                new_goods.status=CLOSED;
                new_goods.price=0;
                new_goods.seller=buyerAddr;
                new_goods.index=vector::length(&buyerMkt.goods_list);
                vector::push_back(&mut buyerMkt.goods_list,new_goods);
            }
        }

        // check all goods info in a market
        public fun check_market_details(mktAddr:address)acquires Market{
            assert!(exists<Market<Goods>>(mktAddr),1000);
            let mkt=borrow_global<Market<Goods>>(mktAddr);
            let goods_list=&mkt.goods_list;
            let len=vector::length(goods_list);
            if (len==0) {
                debug::print(goods_list);
                return
                };
            let i=0;
            while(i < len){
                let goods=vector::borrow<Goods>(goods_list,i);
                debug::print(goods);
                i=i+1;
            }
        }

        //list all goods in all markets
        public fun list_all_goods()acquires AddrBook,Market{
            let add_book=borrow_global<AddrBook>(admin_address());
            let mkts=&add_book.mktAddresses;
            let mkts_len=vector::length(mkts);
            if (mkts_len==0){return};
            let i=0;
            while(i < mkts_len){
                let mkt_addr=*vector::borrow(mkts,i);
                let Market{goods_list}=borrow_global<Market<Goods>>(mkt_addr);
                let goods_len=vector::length(goods_list);
                if (goods_len==0) {i=i+1;continue};
                let j=0;
                while(j < goods_len){
                    let goods=vector::borrow<Goods>(goods_list,j);
                    j=j+1;
                    debug::print(goods);
                };
                i=i+1;
            }
            
        }
        
    }



// ---------------------------test moduel----------------------

    module test{
            use 0x2::Purchase::publish;
            // use 0x2::Purchase::publish_existing_goods;
            use 0x2::Purchase::order;
            use 0x2::Purchase::init_addr_book;
            // use 0x2::Purchase::check_market_details;
            use 0x2::Purchase::list_all_goods;


            #[test(a=@0x3,_add_a=@0x3,b=@0x4,_add_b=@0x4,admin=@0x2)]
            fun test_funs(a:&signer,_add_a:address,b:&signer,_add_b:address,admin:&signer){
                init_addr_book(admin);
                publish(a,100);
                publish(b,300);
                list_all_goods();
                order(b,200,_add_a,0);
                list_all_goods();
                
            }
    }


}
