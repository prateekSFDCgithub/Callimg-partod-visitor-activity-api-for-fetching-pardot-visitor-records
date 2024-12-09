public class VisitorActivitiesBatch implements Database.Batchable<Map<String, Object>>, Database.AllowsCallouts, Database.Stateful {
    private static final String BUSINESS_UNIT_ID = '0Uv3m000000PAvvCAG';
    private List<Email_Link_Click_Activity__c> emailLinkList = new List<Email_Link_Click_Activity__c>();
    private List<Error_Log__c> errorlogList = new List<Error_Log__c>();
    Private  List<Map<String, Object>> activityList = new  List<Map<String, Object>>();
    Private string NextFileEndpointURL='';
    Datetime now = Datetime.now(); // Current datetime
    Datetime twentyFourHoursAgo = now.addDays(-1);
    String twentyFourHoursAgoISO = twentyFourHoursAgo.format('yyyy-MM-dd\'T\'HH:mm:ssXXX');
    String pardotBaseURL = 'callout:Flow_Actions_for_Pardot/api/v5/objects/visitor-activities';
    String fields = 'id,campaignId,createdAt,updatedAt,prospectId,type,typeName,visitId,visitorId,emailId,customRedirectId,details';
    String ENDPOINT = pardotBaseURL + 
        '?fields=' + EncodingUtil.urlEncode(fields, 'UTF-8') + 
        '&type=1' + 
        '&createdAtAfter=' + EncodingUtil.urlEncode(twentyFourHoursAgoISO, 'UTF-8') +
        '&orderBy=createdAt%20desc';
    
    // default constructor
    public VisitorActivitiesBatch() {
        
    }
    // parameterizedConstructor
    public VisitorActivitiesBatch(String endpointfromFinish) {
        this.NextFileEndpointURL = endpointfromFinish;
    }
    public Iterable<Map<String, Object>> start(Database.BatchableContext BC) {
        system.debug('now: '+now);
        system.debug('twentyFourHoursAgo: '+twentyFourHoursAgo);
        system.debug('twentyFourHoursAgoISO: '+twentyFourHoursAgoISO);
        system.debug('NextFileEndpointURL: ' +NextFileEndpointURL);
        system.debug('Dynamic Endpoint URL: ' + ENDPOINT);
        
        activityList = makeHttpRequest(ENDPOINT);
        return activityList;
    }
    
    public void execute(Database.BatchableContext BC, List<Map<String, Object>> activityList) {
        System.debug('In Execute');
        fetchVisitorActivities(activityList);
    }
    
    public void finish(Database.BatchableContext BC) {
        System.debug('emailLinkList in finish method: ' + emailLinkList);
        if (!emailLinkList.isEmpty()) {
            try {
                insert emailLinkList;
                System.debug('Successfully inserted emailLinkList: ' + emailLinkList);
            } catch (DmlException e) {
                System.debug('Error inserting emailLinkList: ' + e.getMessage());
            }
        } else {
            System.debug(
                'emailLinkList is empty, no records to insert in finish method.'
            );
        }
        
        if (!errorlogList.isEmpty()) {
            try {
                insert errorlogList;
                System.debug('Successfully inserted errorlogList: ' + errorlogList);
            } catch (DmlException e) {
                System.debug('Error inserting errorlogList: ' + e.getMessage());
            }
        } else {
            System.debug(
                'errorlogList is empty, no records to insert in finish method.'
            );
        }
        if(NextFileEndpointURL != ''){
            VisitorActivitiesBatch paramBatch = new VisitorActivitiesBatch(NextFileEndpointURL);
            Database.executeBatch(paramBatch, 1); 
        }
    }
    
    public void fetchVisitorActivities(List<Map<String, Object>> activityList) {
        
        if (activityList != null && !activityList.isEmpty()) {
            for (Map<String, Object> activity : activityList) {
                // Parse createdAt with timezone offset
                String createdAtString = (String) activity.get('createdAt');
                Datetime createdAt = parseIso8601Datetime(createdAtString) != null ? parseIso8601Datetime(createdAtString):null;
                // Check if createdAt is within the last 24 hours
                //if (createdAt < Datetime.now().addHours(-24)) {
                // System.debug(
                // 'Skipping activity as it was created more than 24 hours ago.' +
                //createdAt
                //);
                //continue; // Skip this record if it's older than 24 hours
                // }
                string prospectEmail = fetchprospectData(
                    tryParseInteger(activity.get('prospectId'))
                );
                System.debug('prospectEmail: ' + prospectEmail);
                if (prospectEmail != null) {
                    List<Lead> leadList = [
                        SELECT Id, Email
                        FROM Lead
                        WHERE Email = :prospectEmail
                    ];
                    String leadId = !leadList.isEmpty() ? leadList[0].Id : null;
                    if (leadId != null) {
                        Integer emailId = tryParseInteger(activity.get('emailId'));
                        System.debug('emailId: ' + emailId);
                        String subject = null;
                        if (emailId != null) {
                            subject = fetchEmailData(emailId);
                            System.debug('subject: ' + subject);
                        }
                        Integer campaignId = tryParseInteger(activity.get('campaignId'));
                        String campaignName = campaignId != null
                            ? fetchCampaignData(campaignId)
                            : '';
                        insertEmailLinkClickActivity(
                            String.valueOf(activity.get('prospectId')),
                            createdAt,
                            (String) activity.get('details'),
                            subject,
                            String.valueOf(activity.get('id')),
                            campaignName,
                            leadId
                        );
                    }
                }
            }
        } else {
            System.debug('No visitor activities found.');
        }
    }
    
    public List<Map<String, Object>> makeHttpRequest(String endpoint) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Pardot-Business-Unit-Id', BUSINESS_UNIT_ID);
        
        try {
            Http http = new Http();
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                String responseBody = response.getBody();
                System.debug('Response Body: ' + responseBody);
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                String rawNextFileEndpointURL = (String) jsonResponse.get('nextPageUrl');
                system.debug('rawNextFileEndpointURL: '+rawNextFileEndpointURL);
                if(rawNextFileEndpointURL != '' || rawNextFileEndpointURL!= null){
                    nextFileEndpointURL = rawNextFileEndpointURL.replace('\\', '');
                    System.debug('Cleaned NextFileEndpointURL: ' + nextFileEndpointURL);
                }
                else{
                    nextFileEndpointURL ='' ;
                }
                if (jsonResponse.containsKey('values')) {
                    List<Object> values = (List<Object>) jsonResponse.get('values');
                    List<Map<String, Object>> activityList = new List<Map<String, Object>>();
                    for (Object value : values) {
                        activityList.add((Map<String, Object>) value);
                    }
                    return activityList;
                } else {
                    System.debug('No "values" key found in response: ' + jsonResponse);
                }
            } else {
                System.debug(
                    'Error: HTTP Status ' +
                    response.getStatusCode() +
                    ' - ' +
                    response.getBody()
                );
                errorLog(endpoint, response.getBody(), response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Exception during API callout: ' + e.getMessage());
        }
        return null;
    }
    
    public String fetchEmailData(Integer emailId) {
        System.debug('emailId: ' + emailId);
        String PARDOT_API_URL =
            'callout:Flow_Actions_for_Pardot/api/v5/objects/emails/' +
            emailId +
            '?fields=id,name,subject,clientType,prospectId,listEmailId';
        Map<String, Object> emailData = makeHttpRequestForSingleObject(
            PARDOT_API_URL
        );
        
        return emailData != null ? (String) emailData.get('subject') : null;
    }
    
    public String fetchCampaignData(Integer campaignId) {
        System.debug('campaignId: ' + campaignId);
        String PARDOT_API_URL =
            'callout:Flow_Actions_for_Pardot/api/v5/objects/campaigns/' +
            campaignId +
            '?fields=id,name,isDeleted';
        Map<String, Object> campaignData = makeHttpRequestForSingleObject(
            PARDOT_API_URL
        );
        
        return campaignData != null ? (String) campaignData.get('name') : null;
    }
    public String fetchprospectData(Integer prospectId) {
        System.debug('prospectId: ' + prospectId);
        String PARDOT_API_URL =
            'callout:Flow_Actions_for_Pardot/api/v5/objects/prospects/' +
            prospectId +
            '?fields=id,email,firstName';
        Map<String, Object> prospectData = makeHttpRequestForSingleObject(
            PARDOT_API_URL
        );
        
        return prospectData != null ? (String) prospectData.get('email') : null;
    }
    
    public Map<String, Object> makeHttpRequestForSingleObject(String endpoint) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Pardot-Business-Unit-Id', BUSINESS_UNIT_ID);
        try {
            Http http = new Http();
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                String responseBody = response.getBody();
                return (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            } else {
                System.debug(
                    'Error: HTTP Status ' +
                    response.getStatusCode() +
                    ' - ' +
                    response.getBody()
                );
                errorLog(endpoint, response.getBody(), response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Exception during API callout: ' + e.getMessage());
        }
        return null;
    }
    
    public void insertEmailLinkClickActivity(
        String prospectId,
        Datetime createdAt,
        String url,
        String subject,
        String activityId,
        String campaignName,
        String leadId
    ) {
        List<Email_Link_Click_Activity__c> emailList = [
            SELECT Id
            FROM Email_Link_Click_Activity__c
            WHERE Pardot_Visitor_Activity_ID__c = :activityId
        ];
        if (emailList.isEmpty()) {
            Email_Link_Click_Activity__c emailLink = new Email_Link_Click_Activity__c();
            emailLink.Name = activityId;
            emailLink.Prospects_Id__c = prospectId;
            emailLink.Prospect_Id__c = leadId;
            emailLink.Click_Date__c = createdAt;
            emailLink.Number_of_Clicks__c = 1;
            emailLink.Link_URL__c = url;
            emailLink.Email_Subject__c = subject;
            emailLink.Pardot_Visitor_Activity_ID__c = activityId;
            emailLink.Email_Campaign_Name__c = campaignName;
            emailLinkList.add(emailLink);
            System.debug('Added to emailLinkList: ' + emailLink);
        }
    }
    
    public Integer tryParseInteger(Object value) {
        if (value instanceof Integer) {
            return (Integer) value;
        } else if (value instanceof String) {
            try {
                return Integer.valueOf((String) value);
            } catch (Exception e) {
                System.debug('Error converting String to Integer: ' + e.getMessage());
            }
        }
        return null;
    }
    
    public void errorLog(
        String endpoint,
        String responseBody,
        Integer statusCode
    ) {
        Error_Log__c errorlog = new Error_Log__c();
        errorlog.End_Point__c = endpoint;
        errorlog.Request_Body__c = endpoint;
        errorlog.Method__c = 'GET';
        errorlog.Response_Body__c = responseBody;
        errorlog.Status_code__c = String.valueOf(statusCode);
        errorlogList.add(errorlog);
    }
    
    public Datetime parseIso8601Datetime(String datetimeString) {
        // Return null if the input is null or empty
        if (String.isBlank(datetimeString)) {
            System.debug('Datetime string is null or empty');
            return null;
        }
        
        try {
            if (datetimeString.endsWith('Z')) {
                // UTC format (ends with 'Z')
                return Datetime.valueOfGmt(datetimeString.replace('T', ' ').replace('Z', ''));
            } else {
                // Extract date and time portion, and the offset
                String dateWithoutOffset = datetimeString.substring(0, datetimeString.length() - 6).replace('T', ' ');
                String offset = datetimeString.substring(datetimeString.length() - 6);
                
                // Parse the offset
                Integer offsetHours = Integer.valueOf(offset.substring(1, 3));
                Integer offsetMinutes = Integer.valueOf(offset.substring(4, 6));
                Integer totalOffsetMinutes = (offsetHours * 60) + offsetMinutes;
                
                if (offset.startsWith('-')) {
                    totalOffsetMinutes = -totalOffsetMinutes;
                }
                
                // Adjust the parsed date for the offset
                Datetime gmtDatetime = Datetime.valueOfGmt(dateWithoutOffset);
                return gmtDatetime.addMinutes(-totalOffsetMinutes); // Reverse the offset to convert to GMT
            }
        } catch (Exception e) {
            System.debug('Failed to parse datetime string: ' + datetimeString + ' with error: ' + e.getMessage());
            return null;  // Return null if parsing fails
        }
    }
    
}