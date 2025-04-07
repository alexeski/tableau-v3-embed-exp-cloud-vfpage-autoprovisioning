public with sharing class TableauUserProvisioner {

    private static String TABLEAU_SITE_URL;
    private static String CONTENT_URL;
    private static String authenticationToken;
    private static String siteId;

    // Group name constant
    private static final String GROUP_NAME = 'Salesforce_Automated_Provisioning_Group';
    private static final String API_VERSION = '3.25';

    // Static block to load config from CATokenGenerator
    static {
        loadConfigFromTokenGenerator();
    }

    // Fetch Tableau Config using CATokenGenerator
    private static void loadConfigFromTokenGenerator() {
        // Use the getTableauEnvConfig() method from CATokenGenerator
        List<TableauConnectedApp__mdt> configList = CATokenGenerator.getTableauEnvConfig();
        
        if (!configList.isEmpty()) {
            TableauConnectedApp__mdt config = configList[0];  // Assuming single environment config
            TABLEAU_SITE_URL = config.TableauCloud__c;
            CONTENT_URL = config.SiteName__c;
            System.debug('Loaded Config from TokenGenerator: ' + TABLEAU_SITE_URL + ', ' + CONTENT_URL);
        } else {
            throw new AuraHandledException('No Tableau configuration found in custom metadata.');
        }
    }

    @future(callout=true)
    @RemoteAction
    public static void provisionUserAsUnlicensed(String userEmail) {
        System.debug('Provisioning user as unlicensed: ' + userEmail);
        // Authenticate to Tableau REST API
        authenticateToTableauRestApi();

        // Check if user exists in Tableau
        Boolean userExists = checkUserExists(userEmail);
        System.debug('User exists: ' + userExists);

        if (!userExists) {
            // Create group if it does not exist
            String groupId = getGroupId(GROUP_NAME);
            if (groupId == null) {
                groupId = createGroup(GROUP_NAME);
            }

            // Provision user as unlicensed
            createUserAsUnlicensed(userEmail, groupId);
        } else {
            System.debug('User already exists, no need to create');
        }
    }

    private static void authenticateToTableauRestApi() {
        System.debug('Authenticating to Tableau REST API...');
        // Generate JWT token
        String jwtToken = CATokenGenerator.generateJWT('REST_API');
        System.debug('JWT Token: ' + jwtToken);
    
        // Set API endpoint and headers
        String endpoint = TABLEAU_SITE_URL + '/api/' + API_VERSION + '/auth/signin';
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(endpoint);
    
        // Create authentication payload
        String xmlPayload = '<tsRequest>' +
                            '  <credentials jwt="' + jwtToken + '">' +
                            '    <site contentUrl="' + CONTENT_URL + '" />' +
                            '  </credentials>' +
                            '</tsRequest>';
    
        request.setHeader('Content-Type', 'application/xml');
        request.setBody(xmlPayload);
    
        HttpResponse response = http.send(request);
    
        // Parse XML response
        Dom.Document doc = new Dom.Document();
        doc.load(response.getBody());
        Dom.XmlNode rootNode = doc.getRootElement();
    
        // Get the credentials node
        Dom.XmlNode credentialsNode = null;
        for (Dom.XmlNode child : rootNode.getChildElements()) {
            if (child.getName() == 'credentials') {
                credentialsNode = child;
                break;
            }
        }
    
        if (credentialsNode != null) {
            authenticationToken = credentialsNode.getAttribute('token', null);
            Dom.XmlNode siteNode = null;
            for (Dom.XmlNode child : credentialsNode.getChildElements()) {
                if (child.getName() == 'site') {
                    siteNode = child;
                    break;
                }
            }
    
            if (siteNode != null) {
                siteId = siteNode.getAttribute('id', null);
            }
            System.debug('Authentication successful. Token: ' + authenticationToken + ', Site ID: ' + siteId);
        } else {
            System.debug('Authentication failed. Unable to parse credentials node.');
        }
    }

    private static Boolean checkUserExists(String userEmail) {
        System.debug('Checking if user exists: ' + userEmail);
        // Set API endpoint and headers
        String endpoint = TABLEAU_SITE_URL + '/api/' + API_VERSION + '/sites/' + siteId + '/users?filter=name:eq:' + userEmail;
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(endpoint);
        request.setHeader('X-Tableau-Auth', authenticationToken);
        request.setHeader('Content-Type', 'application/xml');

        HttpResponse response = http.send(request);

        // Check if user exists
        if (response.getStatusCode() == 200) {
            // Parse XML response
            Dom.Document doc = new Dom.Document();
            doc.load(response.getBody());
            Dom.XmlNode rootNode = doc.getRootElement();
            Dom.XmlNode usersNode = null;
            for (Dom.XmlNode child : rootNode.getChildElements()) {
                if (child.getName() == 'users') {
                    usersNode = child;
                    break;
                }
            }

            if (usersNode != null) {
                for (Dom.XmlNode userNode : usersNode.getChildElements()) {
                    if (userNode.getName() == 'user') {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    private static String getGroupId(String groupName) {
        System.debug('Getting group ID for group: ' + groupName);
        // Set API endpoint and headers
        String endpoint = TABLEAU_SITE_URL + '/api/' + API_VERSION + '/sites/' + siteId + '/groups?filter=name:eq:' + groupName;
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(endpoint);
        request.setHeader('X-Tableau-Auth', authenticationToken);
        request.setHeader('Content-Type', 'application/xml');

        HttpResponse response = http.send(request);

        // Check if group exists
        if (response.getStatusCode() == 200) {
            // Parse XML response
            Dom.Document doc = new Dom.Document();
            doc.load(response.getBody());
            Dom.XmlNode rootNode = doc.getRootElement();
            Dom.XmlNode groupsNode = null;
            for (Dom.XmlNode child : rootNode.getChildElements()) {
                if (child.getName() == 'groups') {
                    groupsNode = child;
                    break;
                }
            }

            if (groupsNode != null) {
                for (Dom.XmlNode groupNode : groupsNode.getChildElements()) {
                    if (groupNode.getName() == 'group') {
                        return groupNode.getAttribute('id', null);
                    }
                }
            }
        }
        return null;
    }

    private static String createGroup(String groupName) {
        System.debug('Creating group: ' + groupName);
        // Set API endpoint and headers
        String endpoint = TABLEAU_SITE_URL + '/api/' + API_VERSION + '/sites/' + siteId + '/groups';
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(endpoint);
        request.setHeader('X-Tableau-Auth', authenticationToken);
        request.setHeader('Content-Type', 'application/xml');

        // Create group payload
        String xmlPayload = '<tsRequest>' +
                            '  <group name="' + groupName + '" minimumSiteRole="Viewer" grantLicenseMode="OnLogin" />' +
                            '</tsRequest>';

        request.setBody(xmlPayload);

        HttpResponse response = http.send(request);

        // Check if group is created successfully
        if (response.getStatusCode() == 201) {
            // Parse XML response
            Dom.Document doc = new Dom.Document();
            doc.load(response.getBody());
            Dom.XmlNode rootNode = doc.getRootElement();
            Dom.XmlNode groupNode = null;
            for (Dom.XmlNode child : rootNode.getChildElements()) {
                if (child.getName() == 'group') {
                    groupNode = child;
                    break;
                }
            }

            if (groupNode != null) {
                return groupNode.getAttribute('id', null);
            }
        }
        return null;
    }

    private static void createUserAsUnlicensed(String userEmail, String groupId) {
        System.debug('Creating user as unlicensed: ' + userEmail);
        // Set API endpoint and headers
        String endpoint = TABLEAU_SITE_URL + '/api/' + API_VERSION + '/sites/' + siteId + '/users';
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(endpoint);
        request.setHeader('X-Tableau-Auth', authenticationToken);
        request.setHeader('Content-Type', 'application/xml');
    
        // Create user payload
        String xmlPayload = '<tsRequest>' +
                            '  <user name="' + userEmail + '" siteRole="Unlicensed" />' +
                            '</tsRequest>';
    
        request.setBody(xmlPayload);
    
        HttpResponse response = http.send(request);
    
        // Check if user is created successfully
        if (response.getStatusCode() == 201) {
            System.debug('User created successfully: ' + userEmail);
    
            // Parse XML response to extract user-id
            Dom.Document doc = new Dom.Document();
            doc.load(response.getBody());
            Dom.XmlNode rootNode = doc.getRootElement();
            Dom.XmlNode userNode = null;
            for (Dom.XmlNode child : rootNode.getChildElements()) {
                if (child.getName() == 'user') {
                    userNode = child;
                    break;
                }
            }
    
            if (userNode != null) {
                String userId = userNode.getAttribute('id', null);
                // Add user to group
                addUserToGroup(userId, groupId);
            }
        } else {
            System.debug('Error creating user: ' + response.getBody());
        }
    }
    
    private static void addUserToGroup(String userId, String groupId) {
        System.debug('Adding user to group: ' + userId);
        // Set API endpoint and headers
        String endpoint = TABLEAU_SITE_URL + '/api/' + API_VERSION + '/sites/' + siteId + '/groups/' + groupId + '/users';
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(endpoint);
        request.setHeader('X-Tableau-Auth', authenticationToken);
        request.setHeader('Content-Type', 'application/xml');
    
        // Create user payload
        String xmlPayload = '<tsRequest>' +
                            '  <user id="' + userId + '" />' +
                            '</tsRequest>';
    
        request.setBody(xmlPayload);
    
        HttpResponse response = http.send(request);
    
        // Check if user is added to group successfully
        if (response.getStatusCode() == 201) {
            System.debug('User added to group successfully: ' + userId);
        } else {
            System.debug('Error adding user to group: ' + response.getBody());
        }
    }    
}