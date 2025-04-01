public with sharing class CATokenGenerator {

    public CATokenGenerator() {

    }

    private static TableauConnectedApp__mdt ca;
    private static String ts_ca_iss;
    private static String ts_ca_kid;
    private static String ts_ca_secret;

    @AuraEnabled(cacheable=false)
    public static List<TableauConnectedApp__mdt> getTableauEnvConfig() {
        // DeveloperName is unique id
        List<TableauConnectedApp__mdt> tabEnv = [SELECT DeveloperName, secret__c, kid__c, clientId__c, SiteName__c, TableauCloud__c, AdminUsername__c FROM TableauConnectedApp__mdt];
        
        // Log the ca at index 0
        System.debug('tabEnv: ' + tabEnv[0]);
        // TODO: improve to select using 'SiteName__c' value instead of assuming 1 env and index 0
        ca = tabEnv[0];
        ts_ca_iss = ca.clientId__c;
        ts_ca_kid = ca.kid__c;
        ts_ca_secret = ca.secret__c;
        return tabEnv;
    }
    


    // Get views from custom metadata
    @AuraEnabled(cacheable=false)
    public static List<TableauView__mdt> getViews() {
        // DeveloperName is unique id
        List<TableauView__mdt> views = [SELECT DeveloperName, contentUrl__c, viewName__c FROM TableauView__mdt];
    
        // Log the entire list of views
        // System.debug('Views: ' + views);
        return views;
    }

    // Get views from custom metadata
    @AuraEnabled(cacheable=false)
    public static List<TableauMetric__mdt> getMetrics() {
        // DeveloperName is unique id
        List<TableauMetric__mdt> metrics = [SELECT DeveloperName, metricId__c, metricName__c FROM TableauMetric__mdt];
    
        // Log the entire list of views
        // System.debug('Metrics: ' + metrics);
        return metrics;
    }

    

    // Returns user's email & division (Map)
    // @AuraEnabled annotation makes the method accessible via LWC

    /* 
    Partner/Community/Experience Cloud users are associated with a Contact, which has a relationship to an Account. 
    */
    @AuraEnabled(cacheable=false)
    public static Map<String, String> getUserDetails() {
        // Get the user's division, email, and account name
        User currentUser = [SELECT Email, Division, ContactId, LanguageLocaleKey FROM User WHERE Id = :UserInfo.getUserId()];
        String accountName = '';

        if (currentUser.ContactId != null) {
            // Query the Contact to get the Account Name
            Contact userContact = [SELECT Account.Name FROM Contact WHERE Id = :currentUser.ContactId];
            accountName = userContact.Account.Name;
            // System.debug('Account Name: ' + accountName);
        }

        Map<String, String> userDetails = new Map<String, String>{
            'Email' => currentUser.Email,
            'Division' => currentUser.Division,
            'Account' => accountName,
            'Language' => currentUser.LanguageLocaleKey
        };
        return userDetails;
    }

    // helper to convert comma delimited strings to list
    public static List<String> convertStringToList(String input) {
        return input.split(',\\s*');
    }

    // helper to get authenticated user's Division field for UAF
    public static String getCurrentUserDivision() {
        User currentUser = [SELECT Division FROM User WHERE Id = :UserInfo.getUserId()];
        return currentUser.Division;
    }

    // helper to get authenticated user's Account Name field for UAF
    public static String getCurrentUserAccountName() {
        User currentUser = [SELECT Email, Division, ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        String accountName = '';
        if (currentUser.ContactId != null) {
            // Query the Contact to get the Account Name
            Contact userContact = [SELECT Account.Name FROM Contact WHERE Id = :currentUser.ContactId];
            accountName = userContact.Account.Name;
        }
        return accountName;
    }


             

    @AuraEnabled(cacheable=false)
    public static List<Opportunity> getCurrentUserOpportunities() {
    // Query to fetch opportunities where the current user is the owner
    List<Opportunity> opps = [SELECT Id, Name, CloseDate, Amount FROM Opportunity WHERE OwnerId = :UserInfo.getUserId()];
    return opps;
    }

    // helper to get an authenticated user's username
    public static String getCurrentUserUsername() {
        User currentUser = [SELECT Username FROM User WHERE Id = :UserInfo.getUserId()];
        return currentUser.Username;
    }

    // helper method for base64 url encoding
    private static String base64UrlEncode(Blob input) {
        String output = EncodingUtil.base64Encode(input);
        output = output.replace('+', '-');
        output = output.replace('/', '_');
        output = output.replace('=', '');
        return output;
    }

    // helper to create a list of required Tableau claims
    public static List<String> getTableauClaims(String input) { 
        List<String> scopes;
        if (input == 'SSO') {
            // Add tableau scopes (List)
            scopes = new List<String>{
                'tableau:views:embed',
                'tableau:views:embed_authoring',
                'tableau:metrics:embed',
                'tableau:insights:embed'
            };
        } else if (input == 'REST_API') {
            // Add tableau scopes (List)
            scopes = new List<String>{
                'tableau:content:read',
                'tableau:views:download',
                'tableau:users:*',
                'tableau:groups:*'
            };
        }
        return scopes;
    }
   
    // Returns JWT (String)
    // @AuraEnabled annotation makes the method accessible via LWC 
    @AuraEnabled(cacheable=false)
    @RemoteAction
    public static String generateJWT(String tokenType) {
        // get secret, etc. from custom meta data object 
        getTableauEnvConfig();
    
        // Header (Map)
        Map<String, String> header = new Map<String, String>();
        header.put('alg', 'HS256');
        header.put('iss', ts_ca_iss);
        header.put('kid', ts_ca_kid);
        header.put('typ', 'JWT');
        // Claims (Map)
        Map<String, Object> claims = new Map<String, Object>();
        claims.put('iss', ts_ca_iss);
        // Add expiration
        Datetime now = Datetime.now();
        Datetime exp = now.addMinutes(1);
        claims.put('exp', exp.getTime()/1000); // Convert to seconds
        // Add UUID
        Blob base = Crypto.GenerateAESKey(128);
        String h = EncodingUtil.ConvertTohex(base);
        String uuid = h.SubString(0,8)+ '-' + h.SubString(8,12) + '-' + h.SubString(12,16) + '-' + h.SubString(16,20) + '-' + h.substring(20);
        claims.put('jti', uuid); 
        claims.put('aud', 'tableau');
        if (tokenType == 'SSO') {
            claims.put('sub', getCurrentUserUsername());
            claims.put('user_email', getCurrentUserUsername());
        } else if (tokenType == 'REST_API') {
            claims.put('sub', ca.AdminUsername__c);
        }
        List<String> scp = getTableauClaims(tokenType);
        claims.put('scp', scp);
        // Encode Header and Claims
        String encodedHeader = base64UrlEncode(Blob.valueOf(JSON.serialize(header)));
        String encodedClaims = base64UrlEncode(Blob.valueOf(JSON.serialize(claims)));
        // Create JWT
        String jwt = encodedHeader + '.' + encodedClaims;
        // Sign JWT 
        Blob hmacData = Crypto.generateMac('hmacSHA256', Blob.valueOf(jwt), Blob.valueOf(ts_ca_secret));
        // Encode JWT
        String signature = base64UrlEncode(hmacData);
        // Add signature to JWT
        jwt += '.' + signature;
        return jwt;
    }

    // This method is used to provision a user as unlicensed in Tableau. It extends the CATokenGenerator class,
    //  by calling the TableauUserProvisioner class to provision the user as unlicensed and adding the user to a licensing provisioning group 
    @RemoteAction
    public static void provisionUserAsUnlicensed(String email) {
        TableauUserProvisioner.provisionUserAsUnlicensed(email);
    }
}