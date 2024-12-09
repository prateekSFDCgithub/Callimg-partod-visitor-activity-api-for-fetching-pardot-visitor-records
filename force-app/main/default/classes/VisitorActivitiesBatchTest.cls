@isTest
public class VisitorActivitiesBatchTest {

    // Mock class for positive test cases
    public class VisitorActivitiesPositiveMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('visitor-activities')) {
                response.setBody('{"values": [{"id": "1", "prospect_id": "123", "url": "https://example.com", "email_id": "1", "campaign_id": "1"}]}');
                response.setStatusCode(200);
            } else if (req.getEndpoint().contains('emails')) {
                response.setBody('{"subject": "Test Subject"}');
                response.setStatusCode(200);
            } else if (req.getEndpoint().contains('campaigns')) {
                response.setBody('{"name": "Test Campaign"}');
                response.setStatusCode(200);
            }
            return response;
        }
    }

    // Mock class for negative test cases
    private class VisitorActivitiesNegativeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('visitor-activities')) {
                response.setBody('{"values": []}');
                response.setStatusCode(200);
            } else if (req.getEndpoint().contains('emails')) {
                response.setStatusCode(404);
            } else if (req.getEndpoint().contains('campaigns')) {
                response.setStatusCode(500);
            } else if (req.getEndpoint().contains('prospects')) {
                response.setBody('{"error": "Invalid prospect ID"}');
                response.setStatusCode(400);
            } else {
                response.setStatusCode(404);
            }
            return response;
        }
    }

    // Helper method to set up test data
    private static void setupTestData() {
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'test@example.com'
        );
        insert testLead;
    }


    // Test for positive scenario of fetchVisitorActivities
    @isTest
    static void testFetchVisitorActivitiesPositive() {
               List<Map<String, Object>> activityList = new  List<Map<String, Object>>();

        List<Lead> leadList = [
            SELECT Id, Email
            FROM Lead
          ];
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesPositiveMock());
        setupTestData();
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();
        Test.startTest();
        batch.fetchVisitorActivities(activityList);
        Test.stopTest();
    }

    // Test for negative scenario of fetchVisitorActivities
    @isTest
    static void testFetchVisitorActivitiesNegative() {
              List<Map<String, Object>> activityList = new  List<Map<String, Object>>();

        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesNegativeMock());
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        batch.fetchVisitorActivities(activityList);
        Test.stopTest();
    }

    // Test for positive scenario of makeHttpRequest
    @isTest
    static void testMakeHttpRequestPositive() {
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesPositiveMock());
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        List<Map<String, Object>> result = batch.makeHttpRequest('callout:Flow_Actions_for_Pardot/api/v5/objects/visitor-activities');
        Test.stopTest();
    }

    // Test for negative scenario of makeHttpRequest
    @isTest
    static void testMakeHttpRequestNegative() {
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesNegativeMock());
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        List<Map<String, Object>> result = batch.makeHttpRequest('callout:Flow_Actions_for_Pardot/api/v5/objects/visitor-activities');
        Test.stopTest();
    }

    // Test for positive scenario of fetchEmailData
    @isTest
    static void testFetchEmailDataPositive() {
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesPositiveMock());
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        String subject = batch.fetchEmailData(1);
        Test.stopTest();
    }

    // Test for negative scenario of fetchEmailData
    @isTest
    static void testFetchEmailDataNegative() {
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesNegativeMock());
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        String subject = batch.fetchEmailData(1);
        Test.stopTest();
    }

    // Test for positive scenario of fetchCampaignData
    @isTest
    static void testFetchCampaignDataPositive() {
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesPositiveMock());
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        String campaignName = batch.fetchCampaignData(1);
        Test.stopTest();
    }

    // Test for negative scenario of fetchCampaignData
    @isTest
    static void testFetchCampaignDataNegative() {
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesNegativeMock());
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        String campaignName = batch.fetchCampaignData(1);
        Test.stopTest();
    }

    // Test for insertEmailLinkClickActivity method with positive data
    @isTest
    static void testInsertEmailLinkClickActivityPositive() {
        setupTestData();
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        batch.insertEmailLinkClickActivity(null, Datetime.now(), 'https://example.com', 'Test Subject', 'test-activity-id', 'Test Campaign', null);
        Test.stopTest();
    }

    // Test for insertEmailLinkClickActivity method with missing required fields
    @isTest
    static void testInsertEmailLinkClickActivityNegative() {
        setupTestData();
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        batch.insertEmailLinkClickActivity(null, Datetime.now(), null, 'Test Subject', 'test-activity-id', 'Test Campaign', null);
        Test.stopTest();
    }

    // Test for batch execution with positive scenario
    @isTest
    static void testBatchExecutionPositive() {
        setupTestData();
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesPositiveMock());

        Test.startTest();
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Email_Link_Click_Activity__c> activities = [
            SELECT Id FROM Email_Link_Click_Activity__c
        ];
    }

    // Test for batch execution with negative scenario
    @isTest
    static void testBatchExecutionNegative() {
        setupTestData();
        Test.setMock(HttpCalloutMock.class, new VisitorActivitiesNegativeMock());

        Test.startTest();
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Email_Link_Click_Activity__c> activities = [
            SELECT Id FROM Email_Link_Click_Activity__c
        ];
    }
    @isTest
    static void testParseIso8601DatetimeValid() {
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        Datetime result = batch.parseIso8601Datetime('2023-11-13T07:30:00Z');
        Test.stopTest();
    }
@isTest
    static void testParseIso8601DatetimeInvalid() {
        VisitorActivitiesBatch batch = new VisitorActivitiesBatch();

        Test.startTest();
        Datetime result = batch.parseIso8601Datetime('invalid-date');
        Test.stopTest();
    }
}