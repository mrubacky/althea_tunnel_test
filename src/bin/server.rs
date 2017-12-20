extern crate althea_kernel_interface;

use std::net::{TcpListener, SocketAddr, IpAddr};
use std::io::prelude::*;
use std::net::Shutdown;
use std::str::from_utf8;
use althea_kernel_interface::KernelInterface;

fn main() {
//    let priv_key = String::from("iDYXWP4EuA1OGiXlXkYlfx3O7l1GTK7wJpVdtOnFi3E=");//E
//    let pub_key = String::from("DhhaSXlwyFviC4kWjOTKtc7KHxCgSYHVoRC7lPOn9zU=");
    let mut ki = KernelInterface::new();
    let (priv_key, pub_key) = ki.get_keypair().unwrap();
    let a = TcpListener::bind(":::11492").unwrap();
    let mut incoming = a.accept().unwrap();
    let mut conn = incoming.0;
    let mut destination = incoming.1;
    conn.write("ALTHEA KEY EXCHANGE\n".as_bytes());
    let mut buf : Vec<u8> = vec![0; 128];
    conn.read(&mut buf).unwrap();
    if buf[0] == 1 {
        conn.write(pub_key.as_bytes());
        buf = vec![0; 128];
        let len = conn.read(&mut buf).unwrap();
        println!("len is: {}", len);
        buf.truncate(len);
    } else {
        conn.write("protocol mismatch".as_bytes());
        conn.shutdown(Shutdown::Both);
    }
    let remote_pub_key = String::from_utf8(buf).unwrap();
    let local_sock = ki.get_port_and_ip_from_key(&pub_key);
    let remote_sock = ki.get_port_and_ip_from_key(&remote_pub_key);
    ki.setup_wg(
        &destination.ip(),
        &local_sock,
        &remote_sock,
        &priv_key,
        &remote_pub_key);
    println!("{}", local_sock.ip());
    println!("{}", remote_sock.ip());
}