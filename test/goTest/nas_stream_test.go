package test

import (
	"bytes"
	"io"
	"testing"

	nasIE "github.com/free5gc/nas/ie"
	nas "github.com/free5gc/nas/message"
	"github.com/free5gc/openapi/models"
	"github.com/stretchr/testify/require"
)

func TestNasTCPFraming(t *testing.T) {
	first := []byte{0x7e, 0, 0x54}
	second := []byte{0x7e, 0, 0x43}
	stream := append(encapNasMsgToEnvelope(first), encapNasMsgToEnvelope(second)...)
	for _, fragmented := range []bool{false, true} {
		var reader io.Reader = bytes.NewReader(stream)
		if fragmented {
			reader = oneByteReader{reader}
		}
		a, err := readNasEnvelope(reader)
		require.NoError(t, err)
		require.Equal(t, first, a)
		b, err := readNasEnvelope(reader)
		require.NoError(t, err)
		require.Equal(t, second, b)
		_, err = readNasEnvelope(reader)
		require.ErrorIs(t, err, io.EOF)
	}
	for _, truncated := range [][]byte{{0}, {0, 3, 0x7e}, {0, 0}, {0, 2, 0x7e, 0}} {
		_, err := readNasEnvelope(bytes.NewReader(truncated))
		require.Error(t, err)
	}
}

type oneByteReader struct{ io.Reader }

func (r oneByteReader) Read(b []byte) (int, error) {
	if len(b) > 1 {
		b = b[:1]
	}
	return r.Reader.Read(b)
}

func TestNasTCPConfigurationAndAccept(t *testing.T) {
	// Mandatory fields from the NAS library's valid PDU session accept fixture.
	gsm := []byte{0x2e, 0x0a, 0, 0xc2, 0x11,
		0, 9, 1, 0, 6, 0x31, 0x31, 1, 1, 0xff, 9,
		6, 1, 3, 0xe8, 1, 3, 0xe8,
		0x29, 5, 1, 10, 60, 0, 6}
	for _, fragmented := range []bool{false, true} {
		ue := NewRanUeContext(UE_IMSI, 1, nas.AlgCiphering128NEA0, nas.AlgIntegrity128NIA2,
			models.AccessType_NON_3_GPP_ACCESS)
		core := nas.NewSecCtx(nas.CoreNetworkSide, ue.GetBearerType(), ue.CipheringAlg,
			ue.IntegrityAlg, ue.KnasEnc[:], ue.KnasInt[:])
		var stream []byte
		for _, m := range []nas.Message{
			&nas.CfgUpdateCmd{},
			&nas.DLNASTransport{
				PayloadCntrType: &nasIE.PayloadCntrType{Value: nasIE.PayloadCntrType_N1SMInfo},
				PayloadCntr:     &nasIE.PayloadCntr{Contents: gsm},
			},
		} {
			payload, err := nas.Marshal(m, core, nas.SecHdrTypeIntegrityProtectedAndCiphered)
			require.NoError(t, err)
			stream = append(stream, encapNasMsgToEnvelope(payload)...)
		}
		var reader io.Reader = bytes.NewReader(stream)
		if fragmented {
			reader = oneByteReader{reader}
		}
		accept, err := readPDUSessionEstablishmentAccept(ue, reader)
		require.NoError(t, err)
		address, err := GetPDUAddress(accept)
		require.NoError(t, err)
		require.Equal(t, "10.60.0.6", address.String())
	}
}
