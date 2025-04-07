trigger TableauUserProvisioningTrigger on User (after insert) {
    // Collect all Profile Ids from the inserted Users.
    Set<Id> profileIds = new Set<Id>();
    for (User u : Trigger.new) {
        profileIds.add(u.ProfileId);
    }
    
    // Query the relevant profiles.
    Map<Id, Profile> profileMap = new Map<Id, Profile>(
        [SELECT Id, Name FROM Profile WHERE Id IN :profileIds]
    );
    
    // Evaluate each new User using their profile's name.
    for (User newUser : Trigger.new) {
        Profile prof = profileMap.get(newUser.ProfileId);
        String lowerName = prof.Name.toLowerCase();

        if (prof != null && lowerName.contains('customer community') || lowerName.contains('customer portal')) {
            // Invoke the provisioner method.
            TableauUserProvisioner.provisionUserAsUnlicensed(newUser.Email);
        }
    }
}