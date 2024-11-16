

const url = "https://gist.githubusercontent.com/tokenlin/c0776b9dd37aa26415ab70f2888496e9/raw/056ab4e5532fb51c1447706253195a61dd3ed62a/code2.txt";


const codeRequest = await Functions.makeHttpRequest({
  url: url
});

if (codeRequest.error) {
  console.error(codeRequest.error);
  throw Error(`Get text failed`);
  }

var code = decodeURIComponent(codeRequest.data.text);  // get the code
code = code + "\n return [toBytes32StrLength, keccak256, inverseOf, CurveBabyJubJub];";

const returnFunction = new Function([],code);
const [toBytes32StrLength, keccak256, inverseOf, CurveBabyJubJub] = returnFunction();


// ******************submit to chainlink***************** 
const kH_input_0 = BigInt(args[0]);
const kH_input_1 = BigInt(args[1]);
const privateKeyRaw = secrets.apiKey;
const privateKey = keccak256(privateKeyRaw);

let myCurve = new CurveBabyJubJub();
let kH = myCurve.scalarMulAny(inverseOf(BigInt(privateKey), myCurve.L), [kH_input_0, kH_input_1]);

let returnStr = toBytes32StrLength(kH[0].toString(16));
returnStr = returnStr + toBytes32StrLength(kH[1].toString(16));

return Functions.encodeString(returnStr);