use dep::aztec::macros::aztec;

#[aztec]
pub contract CallbackInterface {
    use dep::aztec::macros::functions::external;

    #[external("public")]
    fn callback(_message: Field) {
    }
}
