import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import "."

Window {
    id: window
    visible: true
    width: 393
    height: 852
    title: "RedaVia VPN"
    color: "#071224"

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: onboardingPage
    }

    Component {
        id: onboardingPage
        OnboardingPage {
            onGetStartedClicked: stackView.replace(loginPage)
        }
    }

    Component {
        id: loginPage
        LoginPage {
            onSignInClicked: stackView.replace(homeDisconnectedPage)
        }
    }

    Component {
        id: homeDisconnectedPage
        HomeDisconnected {
            onConnectPressed: stackView.replace(homeConnectedPage)
            onServerChangeRequested: stackView.push(locationsPage)
        }
    }

    Component {
        id: homeConnectedPage
        HomeConnected {
            onDisconnectPressed: stackView.replace(homeDisconnectedPage)
        }
    }

    Component {
        id: locationsPage
        LocationsPage {
            onServerSelected: stackView.pop()
        }
    }

    Component {
        id: subscriptionPage
        SubscriptionPage {}
    }

    Component {
        id: profilePage
        ProfilePage {}
    }

    Component {
        id: trafficDashboardPage
        TrafficDashboard {}
    }
}
