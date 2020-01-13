<?php

namespace App\Factory;

use App\Entity\User;
use App\Enum\Roles;
use App\Form\Model\Registration;

class UserFactory
{
    public static function fromRegistration(Registration $registration): User
    {
        $user = self::create($registration->getEmail(), $registration->getPlainPassword());

        return $user;
    }

    public static function create(string $email, string $plainPassword): User
    {
        $user = new User();
        $user->setEmail(strtolower($email));
        $user->setPlainPassword($plainPassword);
        $user->setRoles([Roles::USER]);

        return $user;
    }
}
