extern crate althea_kernel_interface;

use althea_kernel_interface::KernelInterface;
use std::str;
use std::net::IpAddr;

fn main() {
    let mut ki = KernelInterface::new();
    match ki.open_tunnel("2001::2".parse::<IpAddr>().unwrap()) {
        Ok(m) => println!("Success!"),
        Err(e) => panic!("{:?}", e)
    }
}