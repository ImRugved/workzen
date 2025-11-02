// class Global {
//   //testing
//   //static const hostUrl = "https://vidharbhaseva.com/api"; // manali
//   //local

//   //static const hostUrl = "http://192.168.0.120:8000/api/"; // manali
//   //static const hostUrl = "http://192.168.0.126:8000/api/"; //pramod
//   // static const hostUrl = "http://192.168.0.122:8000/api/"; // my
//   //static const hostUrl = "http://192.168.0.104:8000/api/"; // hp my
//   // static const hostUrl = "http://192.168.26.109:8000/api/"; // hp my hots
//   //static const hostUrl = "http://192.168.0.132:8000/api/"; // abhishek
//   // static const hostUrl = "http://192.168.0.135:8000/api/"; // krish

//   static String hostUrl = "";
//   static String imagePath = "";
//   static String docPath = "";

//   static setAPIConfigTo({required AppEnvironment environment}) {
//     switch (environment) {
//       case AppEnvironment.production:
//         hostUrl = "https://vidharbhaseva.com/api";
//         docPath = "https://vidharbhaseva.com/";

//         break;
//       case AppEnvironment.development:
//         hostUrl =
//             //local

//             // "http://192.168.0.120:8000/api/"; // manali
//             // "http://192.168.0.126:8000/api/"; //pramod
//             //  "http://192.168.0.122:8000/api/"; // my
//             //"http://192.168.0.100:8000/api/"; // hp my
//             // "http://192.168.86.184:8000/api/"; // hp my hots
//             // "http://192.168.0.132:8000/api/"; // abhishek
//             //"http://192.168.0.135:8000/api/"; // krish
//             "http://10.84.165.209:8000/api/";
//         docPath = "http://10.84.165.209:8000/";

//         break;
//       case AppEnvironment.uat:
//         hostUrl = "https://vidharbhaseva.com/api";
//         docPath = "https://vidharbhaseva.com/api";
//         break;
//       case AppEnvironment.qa:
//         hostUrl = "https://vidharbhaseva.com/api";
//         docPath = "https://vidharbhaseva.com/api";
//         break;
//       case AppEnvironment.promod:
//         hostUrl = "http://192.168.0.111:8000/api/";
//         docPath = "http://192.168.0.111:8000/";
//         break;
//       case AppEnvironment.krishna:
//         hostUrl = "http://192.168.0.135:8000/api/";
//         docPath = "http://192.168.0.135:8000/";
//         break;
//       case AppEnvironment.abhishek:
//         hostUrl = "http://192.168.0.132:8000/api/";
//         docPath = "http://192.168.0.132:8000/";
//         break;
//     }
//   }

//   //login api
//   static const login = '/userlogin';

//   //very
//   static const verifyOtp = '/verify_otp';
//   //signup api
// //  static const signup = '/signup';
//   //forgot password api
//   //static const forgotPassword = '/forgot_password';
//   //reset password api
//   //static const setPassword = '/reset_password';
// //slider images and videos
//   static const String getSliderData = '/imgs-videos';
//   //get testimonials
//   static const String getTestimonials = '/testimonials';

//   //get top performer
//   static const String getTopPerformer = '/top-performers';
//   // Installation APIs
//   static const String getAllInstallations = '/orders';
//   // get installation details (append order_id)
//   static const getInstallationDetails = '/orders?order_id=';
//   //get order stages
//   static const getOrderStages = '/orders/:order_id/progress';

//   // get all user payments
//   static const getAllPayments = '/payments';
//   // get specific payment details (optional, not required)
//   static const getPaymentDetails = '/payment_schedule';
// //get service paymets
//   static const getServicePayments = '/service-payments';
//   // get AMC details
//   static const getAmcDetails = '/amc_subscription';

//   // post AMC request
//   static const postAmcRequest = '/amc_request';

//   // post repair request
//   static const createRepairRequest = '/repair_request';
//   // get repair request list
//   static const getRepairRequests = '/repair_requests';

//   // edit repair request list
//   static const editRepairRequests = '/repair_requests';
//   // get repair request details (append request_id)
//   static const getRepairRequestDetails = '/repair_requests';
//   // make sservice payemrny
//   static const makePayment = '/service-payments';
// //get insurance
//   static const getInsurance = '/insurance?order_id=';
//   // get referral summary
//   static const getReferralSummary = '/user/referrals/:user_id';
//   // get referral list
//   static const getReferralList = '/user/referral_list/:user_id';

//   // create referral (lead)
//   static const createReferral = '/leads';
//   // request point encashment
//   static const encashRequest = '/encash_request';
//   // get encashment history
//   static const getEncashmentHistory = '/encash_request';

//   // get user profile
//   static const getUserProfile = '/users';
//   // update user profile (append user_id)
//   static const updateUserProfile = '/users/';

//   // get packages
//   static const getPackages = '/packages';

//   //request Quotation
//   static const requestQuotation = '/leads';

//   //get bank details
//   static const getBankDetails = '/users/:user_id/bankdetails';

//   //update bank details
//   static const updateBankDetails = '/bankdetails/:bank_id';

//   //get document list
//   static const getDocuments = '/users/:user_id/documents';

//   //add comments
//   static const quotationComment = '/quotation/:ref_id/comments';
//   static const leadComment = '/lead/:ref_id/comments';
//   static const orderComment = '/repair_req/:ref_id/comments';

//   //get referral tree
//   static const getReferralTree = '/users/:user_id/referral-tree';
// // get wallet history
//   static const getWalletHistory = '/wallet_transaction';
//   //get referal points
//   static const getReferralPoints = '/referrals';

//   //top perfomar of the week
//   static const getTopPerformers = '/top_performers';
//   //get comment by type and ref id
//   static const getCommentByTypeAndRefId = '/:type/:ref_id/comments';

//   //   type can be: 'insurance','bank_loan','lead','order','quotation','repair_req','subsidy'

//   // ref_id will be respective id as per the type
// }

// enum AppEnvironment {
//   production,
//   development,
//   uat,
//   qa,
//   promod,
//   krishna,
//   abhishek
// }
