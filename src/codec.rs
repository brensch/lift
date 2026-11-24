//! The codec every service and client of ours uses: tonic's protobuf codec
//! with small buffers to start. tonic gives each stream an 8 KB buffer each
//! way by default, which for a million phones idling on their Sync streams
//! (a heartbeat every 30 s, a few bytes each) is most of what the server
//! holds for them. These start at 256 bytes and grow as a message needs.

use std::marker::PhantomData;

use prost::Message;
use tonic::codec::{BufferSettings, Codec, ProstCodec};

/// Bytes a stream's buffers start at, each way.
const START: usize = 256;
/// tonic's own: bytes buffered before a stream yields to others.
const YIELD_AT: usize = 32 * 1024;

pub struct LeanCodec<T, U>(PhantomData<(T, U)>);

impl<T, U> Default for LeanCodec<T, U> {
    fn default() -> Self {
        Self(PhantomData)
    }
}

impl<T, U> Codec for LeanCodec<T, U>
where
    T: Message + Send + 'static,
    U: Message + Default + Send + 'static,
{
    type Encode = T;
    type Decode = U;
    type Encoder = <ProstCodec<T, U> as Codec>::Encoder;
    type Decoder = <ProstCodec<T, U> as Codec>::Decoder;

    fn encoder(&mut self) -> Self::Encoder {
        ProstCodec::<T, U>::raw_encoder(BufferSettings::new(START, YIELD_AT))
    }

    fn decoder(&mut self) -> Self::Decoder {
        ProstCodec::<T, U>::raw_decoder(BufferSettings::new(START, YIELD_AT))
    }
}
